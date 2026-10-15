# Portal growth and expiry

The preserved 1.14 executable is the behavioral reference. Its bytes remain unchanged (SHA256 `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`). This is a bounded recovery of lifecycle fields, not a working original iOS app or a claim of complete portal equivalence.

Original functions executed by `tools/native_portal_lifecycle_reference.py`:

| Function | Address | Recovered behavior |
| --- | --- | --- |
| CPortalGates constructor | 0x9bcc4 | Stopped Blue/Red effect at uniform scale0.3; minimum0.5/maximum1; opening timer half the reload; closing timer one reload; untrimmed height82. |
| CPortal constructor | 0x9c7bc | Active duration, optional supplied up_wizard multiplier and initially unconnected/undeleted flags. |
| ConnectPortalGates | 0x9c8ac | Both state2, linked gates, connected flag and optional original opening sound. |
| CPortal.Update | 0x9c8f0 | Only connected, undeleted pairs advance. Nonpermanent lifetime decrements by float32 elapsed time; expiry sets both state4 before gate updates. Both state3 marks the pair deleted. |
| CPortalGates.Update | 0x9c640 | Active state2 grows from0.5 to1 over half a reload. State4 shrinks from1 to0 over a full reload; zero marks state3. |
| Interpolate | 0x1105e4 | Separate float32 subtraction/multiplication/addition and target-side clamp. |

The loaded catalog supplies reload1000ms/duration15000ms; executable static defaults800/20000 are not substituted for loaded values. Seventeen cases/2,210 update frames include both reloads, fractional reload, zero/small/large elapsed steps, early expiry, supplied upgrade multiplier, inactive, unconnected and permanent pairs. Effect/frame metadata, player lookup, animation play/stop, sound, registration and CheckForTransfer are explicit stubs. Full constructor and update arithmetic executes, including original interpolation. Frame pointer/resource construction and transfer internals do not.

Full room AddPortal0xd95f0 and AddStaticPortal0xd1c04 show activation, connection and static permanent flags. Manager UpdateAllPortals0x9d008 checks the deleted flag before calling Update: a newly deleted pair remains until the following manager update. RenderBefore0x9c77c skips state3; drawing remains in the independently recovered registered before pass.

`portal_view.gd` retains float32 state/timers/scale. Real simulation placement holds the first gate at0.3 until connection, grows both gates, stops new entry transfers during closing, hides zero-sized gates and removes the pair on the next update. Static pairs grow and remain permanent. Pause retains the full state. Native drawing multiplies both axes uniformly; source assets are not stretched.

The source unit passes38,160 checks, including all original fixture frames and real pending/connection/pause/expiry/removal/static bridges. JSON fixture floating values are rounded back to float32 before exact comparison; the initial unrounded decimal comparison failure is retained. An initial helper name collided with Object.connect; its parse failure is also retained. No tolerance is added to source state arithmetic. All ten native r113 suites pass, including418 presentation checks/145 PNGs and73 audio checks/23 WAVs. All eight new lifecycle poses were inspected. Live median gate, zero-stall guards and nine frozen renderer RGBA comparisons pass; protected saves/package/signature/isolation/cleanup remain unchanged. builds/portal-lifecycle-r113-native-suites.json and builds/presentation-comparison-r113-review.json bind the evidence.

Original creep transfer queues, shrink/move/grow behavior, reentry rules, full animator clock/alpha compositing, sound routing, mutable registry ties and GPU sampling remain unresolved. The existing immediate transport behavior and reconstructed frame-age bridge remain explicit approximations. A portal's lifecycle scale does not establish those other behaviors.
