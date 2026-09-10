# Validate an app feature

Provider-neutral task reference. Replace `APP` with `apps/<name>`; this
file does not require a host slash-command registration.

Run `tdd-set/bin/gate.sh APP` and report its actual result. Gate success
is required evidence, but independent review of the resulting HEAD is also
required before feature completion. Use `review.sh APP` when review remains
pending. Do not change tests or approval state to obtain a pass.
