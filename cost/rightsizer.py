#!/usr/bin/env python3
"""
rightsizer.py — flag over-provisioned and idle Kubernetes workloads.

Operational problem (multi-cloud SaaS, many customer instances):
    Requests are set once at deploy and rarely revisited, so clusters run
    far hotter on paper than in reality. Across many instances this is the
    single biggest source of silent cloud spend.

What this does:
    Compares each workload's CPU/memory *requests* against observed *usage*
    (here: a metrics snapshot you can pull from Prometheus or
    `kubectl top`). Flags workloads where requests dwarf real usage and
    estimates the monthly waste, with a suggested right-sized request.

This is a standalone analyzer with sample input so it runs anywhere; in a
real cluster you'd feed it `kubectl top pods` or a Prometheus query instead
of the bundled JSON.

Usage:
    python3 rightsizer.py --input sample_usage.json
    python3 rightsizer.py --input sample_usage.json --threshold 0.4
"""

import argparse
import json
import sys

# Rough EU on-demand blended rates; override with --cpu-cost / --mem-cost.
DEFAULT_CPU_COST_PER_CORE_MONTH = 24.0   # USD per vCPU-month
DEFAULT_MEM_COST_PER_GB_MONTH = 3.2      # USD per GB-month


def analyze(workloads, threshold, cpu_cost, mem_cost):
    findings = []
    total_waste = 0.0
    for w in workloads:
        name = w["name"]
        replicas = w.get("replicas", 1)
        cpu_req = w["cpu_request_cores"]
        mem_req = w["mem_request_gb"]
        cpu_used = w["cpu_used_cores"]
        mem_used = w["mem_used_gb"]

        cpu_util = cpu_used / cpu_req if cpu_req else 1.0
        mem_util = mem_used / mem_req if mem_req else 1.0

        # Only flag if BOTH dimensions are under-utilised (avoid right-sizing
        # a memory-bound service down on CPU and starving it).
        if cpu_util < threshold and mem_util < threshold:
            # suggest request = p-ish headroom over observed usage (1.3x)
            sug_cpu = round(cpu_used * 1.3, 3)
            sug_mem = round(mem_used * 1.3, 3)
            cpu_saved = (cpu_req - sug_cpu) * replicas * cpu_cost
            mem_saved = (mem_req - sug_mem) * replicas * mem_cost
            waste = max(0.0, cpu_saved + mem_saved)
            total_waste += waste
            findings.append({
                "workload": name,
                "replicas": replicas,
                "cpu_util": round(cpu_util, 2),
                "mem_util": round(mem_util, 2),
                "current_cpu": cpu_req,
                "suggested_cpu": sug_cpu,
                "current_mem_gb": mem_req,
                "suggested_mem_gb": sug_mem,
                "est_monthly_saving_usd": round(waste, 2),
            })
    return findings, round(total_waste, 2)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--threshold", type=float, default=0.5,
                   help="Utilisation below this (both cpu & mem) flags waste.")
    p.add_argument("--cpu-cost", type=float, default=DEFAULT_CPU_COST_PER_CORE_MONTH)
    p.add_argument("--mem-cost", type=float, default=DEFAULT_MEM_COST_PER_GB_MONTH)
    args = p.parse_args()

    with open(args.input) as f:
        workloads = json.load(f)

    findings, total = analyze(workloads, args.threshold, args.cpu_cost, args.mem_cost)

    if not findings:
        print("No over-provisioned workloads found at threshold "
              f"{args.threshold:.0%}.")
        return

    print(f"Right-sizing report (threshold {args.threshold:.0%} utilisation)\n")
    hdr = (f"{'workload':22}{'cpu%':>6}{'mem%':>6}"
           f"{'cpu req->sug':>16}{'mem req->sug':>16}{'$/mo':>10}")
    print(hdr)
    print("-" * len(hdr))
    for f in findings:
        cpu_col = f"{f['current_cpu']:.2f}->{f['suggested_cpu']:.2f}"
        mem_col = f"{f['current_mem_gb']:.2f}->{f['suggested_mem_gb']:.2f}"
        print(f"{f['workload']:22}"
              f"{f['cpu_util']*100:5.0f}%{f['mem_util']*100:5.0f}%"
              f"{cpu_col:>16}{mem_col:>16}"
              f"{f['est_monthly_saving_usd']:10.2f}")
    print("-" * len(hdr))
    print(f"Estimated total monthly saving: ${total:,.2f}")


if __name__ == "__main__":
    sys.exit(main())
