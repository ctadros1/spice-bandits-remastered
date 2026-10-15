# Offline campaign prerequisites

Reference: decrypted Spice Bandits1.14 ARMv7 executable SHA256 `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. `TDPlayer::hasUnlock`0x44558 and `hasSingleUnlock`0x4449c were checked against assembly, including the comma and exclamation CFStrings at0x4458c/0x445c2/0x4468c.

Without a comma, the empty expression is available and other expressions compare literally against the unlock array. With a comma, ordinary tokens are alternatives: owning any one is sufficient. A token prefixed by`!` is a mandatory **positive** unlock. A missing mandatory token returns false immediately; a present mandatory token sets the result true. It is not negation. The literal no-comma expression`!a` still compares as`!a`, matching the native branch. Whitespace and empty list components are retained.

This makes Barricade's`!mo6_sp,!pass7_af` require the Buenos Aires Normal win and Africa pass. Rubber Factory's`mo31_sp,mo31_ao` permits either Hello Mario Normal or Air Attack. The football bonus permits any listed mode completion, including the recovered Normal schedule. Previously the reconstruction treated the full expression as one literal token, blocking these locations.

## Explicit offline access bridges

Exactly two of148 recovered missions have prerequisites that no set of recovered offline completion tokens can satisfy. The source requirements remain unchanged. The local profile applies two narrowly scoped virtual access tokens:

| Configuration | Preserved requirement | Offline adaptation |
| --- | --- | --- |
|81, Hello Mario Sudden Death |`!mo31_ao,!30_sd` | Treat completed`mo30_sd` as the required`30_sd` spelling only when checking this mission. The other requirement remains mandatory. |
|286, Fracture Air Attack |`mo40_ao` | Its predecessor's Air Attack schedule is absent from all preserved offline configurations. Permit the corresponding location's Normal completion`mo40_sp` to satisfy this access check. |

These are access adaptations, not recovered server rules. They never add fabricated wins, stars or permanent unlock tokens to the save. They allow all148 recovered schedules to be reached while preserving every original file and requirement string. No substitute mission or expansion level is introduced.

Focused checks cover both native parser branches, ordinary alternatives, mandatory requirements, real Barricade/Rubber Factory/bonus cases, both virtual bridges and all148 access checks. The unmodified source prerequisites admit146 of148 schedules from the complete recovered token set; the explicit bridges admit148. This establishes access reachability, not a winning campaign traversal or original server reconciliation.
