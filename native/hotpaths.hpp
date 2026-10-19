#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace godot {
class SpiceNative : public RefCounted {
    GDCLASS(SpiceNative, RefCounted)
protected:
    static void _bind_methods();
public:
    static bool advance_normal_walk(Dictionary actor, double dt_ms, Dictionary map);
    static bool advance_creep_fields(Dictionary actor, double dt_ms, int64_t remaining);
    static bool frame_clock_advance(Dictionary state, double dt_ms);
    static bool in_range(Vector2 a, Vector2 b, double radius, double hex_height);
    static PackedInt32Array range_candidates(Array entries, Vector2 position, double radius, double hex_height, int aim);
    static Dictionary select_target(Array entries, Dictionary query, Callable grid);
    static Dictionary movement_tick(Vector2 start, Vector2 target, Vector2 future, double progress, double carry, double speed, double dt, double hex_height);
    static double creep_depth(double center_y, double height);
    static double creep_light(double current, double target, double progress);
    static Vector2 creep_missile_origin(Vector2 input, Vector2 target);
    static void creep_missile_tick(Dictionary missile, double dt, double raw_velocity = 3000);
    static void update_particle(Dictionary particle, Dictionary definition, double dt, double age);
    static void update_particles(Array particles, Dictionary definition, double dt, double clock_ms);
    static void advance_systems(Array systems, double clock_ms, Callable emit_child, Callable emit_batch, RandomNumberGenerator *random = nullptr, double dt = 0.03);
    static void emit_batch(Dictionary system, double clock_ms, RandomNumberGenerator *random);
    static int64_t compile_particle(Dictionary definition);
    static Array particle_batches(Array systems, bool premultiplied, double clock_ms, Vector2 origin, double zoom, bool mesh_color_quantization = false, bool reference_keys = false, bool coalesce_owned = true);
    static Dictionary particle_spawn_fields(Dictionary system,int64_t index,RandomNumberGenerator *random);
    static void owned_particle_emit(Dictionary system,int64_t count,Callable make_particle,Callable make_child);
    static void owned_particle_advance(Dictionary system,double dt,Callable make_particle,Callable make_child,double interval_scale=1.0,bool prepared=true);
    static bool advance_creep_particles(Array roots,double clock_ms,double dt_ms,Callable make_particle,Callable make_child,bool prepared,bool defer_child_binding);
    static void update_creep_particle_fields(Dictionary actor,Vector2 aim,Vector2 direction,bool heavy);
    static void owned_particle_restart(Dictionary system);
    static void owned_particle_destroy(Dictionary system,Array deleted);
    static Dictionary owned_particle_render(Dictionary root,bool homogeneous);
    static Array owned_particle_batches(Dictionary root,Vector2 origin,double zoom);
    static String format_xp(double value, bool compact = true);
    static Vector2 projected_random_vector(int64_t latitude_rand, int64_t angle_rand);
    static Dictionary bolt_ribbon(PackedVector2Array path, int64_t pass_id, double opacity);
    static Dictionary water_table(int64_t seed);
    static double water_noise(Dictionary table, double value);
    static Dictionary water_vertices(Dictionary table, Dictionary settings, double phase);
};
}
