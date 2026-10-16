# Original pause dispatch and particle rendering

R142 adds bounded original-code evidence. It does not change runtime pause behavior, complete room rendering or establish original-device pixels.

The preserved 1.14 executable remains SHA-256 `e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048`. Both fixtures reproduce byte for byte in independent second executions; executed function bodies and the original file remain unchanged. See `builds/room-particle-pause-r142-reproduction.json`.

## Room update

`native_room_pause_reference.py` executes full `CRoom::Update` at0xd2768 and actual `UpdateGame` at0xd338c across180 supplied single-player rows: five deltas, three speed modes, pause object absent/closed/open, initial stop flag0/1 and room+0x2f0 zero/nonzero. Other readiness/update fields and sentinel clocks are supplied. PauseScreen.Update/IsOpened and subsystem/UI/audio calls are recording stubs. Creeps are recorded at the manager call, not executed here.

When the supplied pause query reports open, all60 rows skip UpdateGame and the creep-manager call. The room delta/global delta remain their prior sentinel bits, room clock/survival stay unchanged and the animation-stop flag becomes1. This is a skipped update, not a zero-delta refresh of particle colors.

All120 other rows call UpdateGame and creeps once. Speed modes0/1/2 supply exact float32 delta products1×/2×/4×. Room+0x2f0 controls whether an existing animation-stop flag is cleared; its meaning remains unidentified. With that supplied field nonzero, gameplay can still update while the animation-stop flag stays1. Do not treat that global flag alone as proof of paused gameplay.

## Particle render wrapper

`native_particle_render_pause_reference.py` executes full `CParticleSystem::Render` at0x111880, recursive FillBuffers and actual short/float packing. Its96 cases cover global animation-stop0/1, root/child real-alpha flags, both buffer formats, parent opacity0/.5/1 and plain/rotated geometry, with two held renders each.

Inputs contain one parent and two children, consistent maximum-count cache, sufficient preallocated buffers and enabled texture metadata. GL/blend/bind calls are recording stubs; trigonometry/AngPos stubs retain the earlier render probe's scope. Allocation and real GPU/atlas behavior are outside these cases.

All192 calls produce17 vertices and one recorded triangle-strip draw. Positions, UV/color bytes and in-place child RGBA exactly match direct original FillBuffers. The wrapper still draws and mutates child colors with either global animation-stop value. Root real-alpha selects source blend1 versus SRC_ALPHA; the child's own flag controls its RGB multiplication separately.

## Remaining caller scope

These executions support retaining the current skipped physics update during pause and the recovered render mutation. They do not execute the full room/Creep renderer, pause-window opening animation, visibility/culling or outer frame-delta producer. An original caller may still determine whether and how often the wrapper runs. Do not claim full paused visual identity, force a zero-delta refresh or introduce an unproven render-epoch cache from these records.

Continue the original retained dying-owner/splash and full caller/room work, together with the remaining gameplay/UI/animation/sound/campaign/progression requirements. The failed performance candidates and exact native renderer comparisons remain separate evidence.
