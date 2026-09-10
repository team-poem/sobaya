# Complete an approved app plan

Provider-neutral task reference. Replace `APP` with `apps/<name>`; this
file does not require a host slash-command registration.

Run `tdd-set/bin/loop.sh APP [max_iterations]` with the selected worker
policy. Continue through validated entries, the final gate, and independent
review. Respect call/time limits and protected inputs. On failure inspect
status and diagnostics; explicit resume follows diagnosis, not a blind retry.
Report completion only when both gate and revision-bound review succeed.
