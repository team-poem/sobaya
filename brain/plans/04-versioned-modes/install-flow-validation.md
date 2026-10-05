# Installed flow implementation evidence

Approved input: b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0.
Both draft and materialized tests remain byte-identical. Tests run with
TMPDIR=/private/tmp so Git/Node canonical paths agree on macOS (the default
/var temporary directory is a symlink). Workers and downloads use the approved
controls; Git, Node, archive validation and existing acceptance gates are real.

## Entry checkpoints

1. install_pins_real_release_and_transport: RED at the installed command's
   explicit unimplemented operation, then GREEN against real tagged archives,
   retained bytes/permissions, consumer preservation, repeat install, and fixed
   HTTPS transport arguments. The complete existing tests/run.sh passed using
   actual Go, Node and the local Vitest dependency tree. Independent focused
   review found missing-parent dotdot containment and missing-launcher holes;
   both were fixed and directly reprobed. Safety validation is part of this
   coherent installer; later rejection entries may already be green.

No later entry has been accepted yet. No v1 release or PR merge performed.
