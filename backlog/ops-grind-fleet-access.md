# Grind drift-checker has no fleet access

**Status (2026-04-10, post-deploy):** RESOLVED for relay1/web2 —
`ssh claude@{relay1,web2}` works (uid 1002, wheel); `kin status`
returns real toplevels. nv1 remains mesh-only/unreachable from the
container (acceptable — desktop, often off).

**Optional follow-up:** enroll the grind container as a maille member
if nv1 drift starts mattering. Otherwise close this.
