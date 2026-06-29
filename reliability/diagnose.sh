#!/usr/bin/env bash
# ============================================================================
# diagnose.sh — first-responder runbook automation for common on-call alerts.
#
# Targets the "rotating on-call" reality named in the job: instead of an
# engineer manually running the same kubectl incantations at 3am, this script
# triages the three most common Kubernetes incidents and takes the safe,
# reversible first action — then reports what it found.
#
# Scenarios handled:
#   1. CrashLoopBackOff      -> show recent logs + last state, optional restart
#   2. Pending/unschedulable -> surface scheduling events (resource? taints?)
#   3. Stuck rollout         -> report status, offer rollback to last revision
#
# Safety: actions that change state (restart, rollback) require --apply.
# Without it the script is read-only and just reports findings.
#
# Usage:
#   ./diagnose.sh <namespace> <deployment>
#   ./diagnose.sh prod pos-sync-worker --apply
# ============================================================================
set -euo pipefail

NS="${1:?usage: diagnose.sh <namespace> <deployment> [--apply]}"
DEPLOY="${2:?usage: diagnose.sh <namespace> <deployment> [--apply]}"
APPLY="${3:-}"

kc() { kubectl -n "$NS" "$@"; }
note() { printf '\n=== %s ===\n' "$1"; }

note "Deployment rollout status"
if ! kc rollout status "deploy/$DEPLOY" --timeout=5s; then
  echo "Rollout not healthy."
  note "Rollout history"
  kc rollout history "deploy/$DEPLOY" || true
  if [ "$APPLY" = "--apply" ]; then
    echo ">> Rolling back to previous revision (--apply set)."
    kc rollout undo "deploy/$DEPLOY"
  else
    echo ">> Re-run with --apply to roll back to the previous revision."
  fi
fi

note "Pods for $DEPLOY"
PODS=$(kc get pods -l "app=$DEPLOY" -o name || true)
echo "${PODS:-<none found; check label selector>}"

for pod in $PODS; do
  PHASE=$(kc get "$pod" -o jsonpath='{.status.phase}')
  WAITING=$(kc get "$pod" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)

  if [ "$WAITING" = "CrashLoopBackOff" ]; then
    note "CrashLoopBackOff: $pod"
    echo "-- last 30 log lines (previous container) --"
    kc logs "$pod" --previous --tail=30 || echo "(no previous logs)"
    if [ "$APPLY" = "--apply" ]; then
      echo ">> Deleting pod to force a clean restart (--apply set)."
      kc delete "$pod"
    else
      echo ">> Re-run with --apply to restart this pod."
    fi
  fi

  if [ "$PHASE" = "Pending" ]; then
    note "Pending (unschedulable?): $pod"
    echo "-- scheduling events --"
    kc describe "$pod" | sed -n '/Events:/,$p' | tail -15
    echo ">> Common causes: insufficient cpu/mem, node selector/taint mismatch, PVC unbound."
  fi
done

note "Recent namespace warning events"
kc get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -10 || true

echo
echo "Triage complete. ${APPLY:+(actions applied)} ${APPLY:-(read-only; use --apply to act)}"
