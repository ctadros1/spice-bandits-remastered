# Medal settlement

Reference: decrypted1.14 ARMv7 executable; source catalog has78 medals. Native medal IDs are catalog positions, so shared artwork is not an identity. Nine secret medals use`secret_find.png` but have distinct keys. The reconstruction uses key/grade identities and retains compatibility with old unique-image identifiers. Award counts live inside the existing stats dictionary, preserving the saved profile's version1 envelope.

`AchTracker::checkForMedals:achieve:`,0x3a0a8, gathers every eligible catalog ID. During a game it queues them. `setInLiveGame:`,0x3a4d4, deduplicates the match queue, keeps the lowest numeric grade for each key, and gives medals only if`gameWon` is true. Statistics are posted even after a loss. `TDServer::modGiveMedal:`,0x462f0, increments a count for each awarded ID, including a previously owned medal. `CWinLoseScreen::Open`,0xbcddc..0xbce28, sums the displayed medals' raw XP awards and calls`addXP` once; that method divides by10. Repeat qualifying wins can therefore repeat medal XP. The prior prototype awarded all eligible global grades immediately and only once; this is corrected.

Tutorial actions are excluded by native guards in EndTowerBuilding0xcaccc, magic placement, kill-chain settlement and the win screen. Kill XP still follows its separate native path. Local lifetime statistics retain their saved values; the port does not retroactively replace old statistics.

| Match condition | Recovered rule |
| --- | --- |
| Kill chain | UpdateKillsInRaw0xe9ae8 resets an integer timer while any owned tower holds a target. A gap strictly greater than300ms closes the current chain; only chains above5 are reported. The simulation records the largest closed chain. Dead-target cleanup and the final victory-frame delay remain a comparison point. |
| Top upgrade | TowerPanel0xee200 increments the match counter on a level2-to3 upgrade whose new resource has neither further branch. Root level3 entries with branches do not count. Selling does not reverse the executed upgrade counter. |
| Money left | Win screen passes the final integer battle balance. Only victory settles it. |
| All families | Win-screen medal update checks six family flags set when building. Sold towers still contribute to those flags. |
| Early waves | Win screen sends10 for all waves early,7 for at least75%,5 for at least50%. Sudden Death all-early adds its separate medal. |
| Secret medals | CheckForSpiceMedals0xbf448 first matches location and mode, then examines remaining towers or the perfect-game flag. Descriptions saying “without building” do not override the final-tower checks. |

Secret predicates are traced: machinegun forms1..3 only; all remaining tower levels1; perfect-game star; exactly one remaining tower; no forms1..3; Duke Nuke type5/level3; three type2/level3 Gatling Superguns; five type8 freeze towers at any level; and no AA forms13..15. Empty tower lists fail the only/without-family challenges. These predicates are exercised separately from real campaign strategy wins.

The port is in`game/scripts/medals.gd`, with transactional settlement/counting in Profile and battle counters in Simulation. Focused verification covers every secret predicate, tier selection, repeat counts/XP, shared-artwork isolation, loss/tutorial exclusions, strict chain timing, terminal upgrades and save rollback. Native medal-board grouping, result presentation and service-derived level/rank thresholds remain separate presentation/progression work.
