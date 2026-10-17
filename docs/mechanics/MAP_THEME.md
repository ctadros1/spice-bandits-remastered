# Original map theme selector

R152 executes full original CMap.GetThemeByName0x103338 (184bytes) and full ismatch0x122020 (40bytes) without stubs.31supplied cases include null/empty/unknown strings, all original names, upper-case/trailing-space mismatches and imported theme names. Every call also runs the original Load assignment slice0xfffa8..0xfffbc (20bytes) with supplied getText return/map/stack pointers. Both methods give identical selectors. All67preserved imported maps are covered. The original XML parser and the rest of Load do not run.

| Exact theme | Selector stored at map+8 |
| --- | --- |
| snow, winter | 1 |
| desert | 2 |
| jungle | 3 |
| forest | 4 |
| urban | 5 |
| sport | 6 |
| null or unknown | 0 |

The original Load pseudocode/disassembly shows this value comes from the map/theme XML child text. The executed assignment slice confirms the actual selector is stored at map+8. Full parser/Load execution remains outside this bounded evidence. Combined with the R149 complete constructor cases, this identifies the white hover RGB condition as snow/winter. R153integrates this mapping at actual spawn;31exact selector cases and all67supplied imported map-theme headers verify actual hover root RGB. Other map fields stay on a valid supplied mission geometry because some preserved unused map definitions lack playable dimensions. No parser/full-Load/playability claim. Full new build/native acceptance remains pending.

Generator tools/native_map_theme_reference.py and fixture tests/fixtures/native-map-theme-reference.json independently repeat byte-exact SHA7cb54c7b3743390377cd437c90634b0624e18c1739e10d0e58e74312b0ff063f (12164bytes). Audit builds/map-theme-r152-reproduction.json. All original bytes and complete executed bodies remain unchanged. Current R151performance failure and accepted R137comparison remain separately preserved.
