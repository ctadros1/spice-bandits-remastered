// Reconstruction hot paths only. The preserved executable is never linked.
#include "hotpaths.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <algorithm>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <string>
#include <cmath>
#include <limits>
#include <cstdio>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/classes/texture2d.hpp>
using namespace godot;
namespace {
inline float f32(double value) { return static_cast<float>(value); }
struct Ellipse {
    float ratio, squared;
    explicit Ellipse(double radius, double hex_height) {
        const float vertical=f32(radius*hex_height);
        const float horizontal=f32(double(vertical)*1.440000057220459);
        ratio=f32(double(horizontal)/vertical);
        squared=f32(double(horizontal)*horizontal);
    }
    bool contains(Vector2 a, Vector2 b) const {
        const float dx=f32(double(b.x)-a.x);
        const float dy=f32(double(f32(double(b.y)-a.y))*ratio);
        return f32(double(f32(double(dx)*dx))+f32(double(dy)*dy))<=squared;
    }
};
struct Keys {
    const StringName count{"count"},frame{"frame"},loop{"loop"},divisor{"divisor"},multiplier{"multiplier"},stopped{"stopped"};
    const StringName grow_ms{"grow_ms"},slow_pending{"slow_pending"},consumed_slow{"consumed_slow"},animation_divisor{"animation_divisor"},animation_multiplier{"animation_multiplier"},freeze_attached{"freeze_attached"},freeze_remaining{"freeze_remaining"},freeze_auxiliary_present{"freeze_auxiliary_present"},freeze_auxiliary_value{"freeze_auxiliary_value"},poison_count{"poison_count"},slow_count{"slow_count"};
    const StringName local_clock_seconds{"local_clock_seconds"},view_clock_ms{"view_clock_ms"},real_alpha{"real_alpha"},color{"color"},size{"size"},life_cycle{"life_cycle"},scale{"scale"},scalable{"scalable"},use_real_size{"use_real_size"},rotational{"rotational"},region{"region"},size_offset{"size_offset"};
    const Variant output_texture{String("texture")},output_vertices{String("vertices")},output_uvs{String("uvs")},output_colors{String("colors")},output_indices{String("indices")},output_fallback{String("fallback")},output_region{String("region")},output_center{String("center")},output_shape{String("shape")},output_rotation{String("rotation")},output_tint{String("tint")};
    const StringName hp{"hp"},state{"state"},aim{"aim"},native_air{"native_air"},air{"air"},owner{"owner"},target_owner{"target_owner"},pos{"pos"},speed{"speed"},slow{"slow"},grid{"grid"},cell{"cell"},next_cell{"next_cell"},progress{"move_progress"};
    const StringName velocity{"velocity"},rotation{"rotation"},rot_speed{"rot_speed"},alpha{"alpha"},born{"born"};
    const StringName definition{"definition"},until{"until"},emitting{"emitting"},particles{"particles"},phase{"phase"},child_released{"child_released"},variation{"variation"},released{"released"},id{"id"},texture{"texture"},coefficients{"native_coefficients"},owner_hidden{"owner_hidden"};
};
const Keys &keys() { static const Keys value;return value; }
struct ParticleCoefficients {
    double gx,gy,wx,wy,raw_life;
    float life,fade,blend;
    bool wind_enabled;
    explicit ParticleCoefficients(const Dictionary &d) {
        const Array gravity=d.get("gravity",Array::make(0,0));
        const Array wind=d.get("wind",Array::make(0,0));
        gx=gravity[0];gy=gravity[1];wx=wind[0];wy=wind[1];
        wind_enabled=d.get("wind_enabled",true);
        // Original lifetime field is float32, including its expiry comparison.
        life=f32(double(d.get("life_cycle",1)));raw_life=double(life);
        fade=f32(double(d.get("fade_in_time",0)));blend=f32(double(d.get("blend_delay",0)));
    }
    float opacity(float age) const {
        float value=1.0f;
        if(blend>0 && age>f32(double(life)/blend)) {
            const float boundary=f32(double(life)/blend);
            value=f32(1.0-double(f32(double(f32(double(age)-boundary))/boundary)));
        } else if(fade>0) {
            value=age<=fade ? f32(double(age)/fade) : f32(1.0-double(f32(double(f32(double(age)-fade))/f32(double(life)-fade))));
        } else if(blend==0) value=f32(1.0-double(f32(double(age)/life)));
        return std::min(1.0f,value);
    }
    void integrate(Dictionary p,double dt,float age) const {
        const Keys &k=keys();
        Vector2 v=p[k.velocity];
        v.x=f32(double(v.x)+f32(gx*dt));v.y=f32(double(v.y)+f32(gy*dt));
        if(wind_enabled) {
            v.x=f32(double(v.x)+f32(double(f32(wx-v.x))*dt));
            v.y=f32(double(v.y)+f32(double(f32(wy-v.y))*dt));
        }
        Vector2 pos=p[k.pos];
        pos.x=f32(double(pos.x)+f32(double(v.x)*dt));pos.y=f32(double(pos.y)+f32(double(v.y)*dt));
        p[k.velocity]=v;p[k.pos]=pos;
        p[k.rotation]=f32(double(p[k.rotation])+f32(double(p[k.rot_speed])*dt));
        p[k.alpha]=opacity(age);
    }
};
struct CompiledParticle {
    ParticleCoefficients particle;
    int64_t disable;
    double interval,amplitude,amplification_speed;
    String child;
    explicit CompiledParticle(const Dictionary &d):particle(d) {
        disable=d.get("disable_after",0);interval=d.get("release_interval",1);
        amplitude=d.get("amplifyX_withSin_by",0);amplification_speed=d.get("amplification_speed",0);
        child=d.get("child_system","");
    }
};
std::vector<CompiledParticle> compiled_particles;
std::unordered_map<std::string,int64_t> particle_ids;
void integrate_particles(Array particles,const ParticleCoefficients &coefficients,double dt,double clock_ms) {
    const Keys &k=keys();int live=0;
    for(int i=0;i<particles.size();++i) {
        Dictionary p=particles[i];
        const float age=f32(double(f32(clock_ms/1000.0))-f32(double(p[k.born])/1000.0));
        if(age>=coefficients.raw_life)continue;
        coefficients.integrate(p,dt,age);
        if(live!=i)particles[live]=p;
        ++live;
    }
    particles.resize(live);
}

}
void SpiceNative::_bind_methods() {
    ClassDB::bind_static_method("SpiceNative",D_METHOD("advance_creep_fields","actor","dt_ms","remaining"),&SpiceNative::advance_creep_fields);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("frame_clock_advance","state","dt_ms"),&SpiceNative::frame_clock_advance);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("creep_depth","center_y","height"),&SpiceNative::creep_depth);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("creep_light","current","target","progress"),&SpiceNative::creep_light);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("creep_missile_origin","input","target"),&SpiceNative::creep_missile_origin);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("creep_missile_tick","missile","dt","raw_velocity"),&SpiceNative::creep_missile_tick,DEFVAL(3000));
    ClassDB::bind_static_method("SpiceNative",D_METHOD("bolt_ribbon","path","pass_id","opacity"),&SpiceNative::bolt_ribbon);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("in_range","a","b","radius","hex_height"),&SpiceNative::in_range);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("range_candidates","entries","position","radius","hex_height","aim"),&SpiceNative::range_candidates);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("select_target","entries","query","grid"),&SpiceNative::select_target);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("movement_tick","start","target","future","progress","carry","speed","dt","hex_height"),&SpiceNative::movement_tick);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("update_particle","particle","definition","dt","age"),&SpiceNative::update_particle);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("update_particles","particles","definition","dt","clock_ms"),&SpiceNative::update_particles);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("advance_systems","systems","clock_ms","emit_child","emit_batch","random","dt"),&SpiceNative::advance_systems,DEFVAL(Variant()),DEFVAL(0.03));
    ClassDB::bind_static_method("SpiceNative",D_METHOD("emit_batch","system","clock_ms","random"),&SpiceNative::emit_batch);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("compile_particle","definition"),&SpiceNative::compile_particle);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("particle_batches","systems","premultiplied","clock_ms","origin","zoom","mesh_color_quantization","reference_keys"),&SpiceNative::particle_batches,DEFVAL(false),DEFVAL(false));
    ClassDB::bind_static_method("SpiceNative",D_METHOD("format_xp","value","compact"),&SpiceNative::format_xp,DEFVAL(true));
    ClassDB::bind_static_method("SpiceNative",D_METHOD("projected_random_vector","latitude_rand","angle_rand"),&SpiceNative::projected_random_vector);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("water_table","seed"),&SpiceNative::water_table);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("water_noise","table","value"),&SpiceNative::water_noise);
    ClassDB::bind_static_method("SpiceNative",D_METHOD("water_vertices","table","settings","phase"),&SpiceNative::water_vertices);
}

String SpiceNative::format_xp(double value,bool compact) {
    // RenderInfoBarIndicators0xd6184 uses float32 division followed by
    // libc formatting. WinLoseScreen::Render0xb9a60 uses unshortened %.0f.
    float amount=f32(value);
    const char *format="%.0f";
    if(compact && amount>=1000000.0f) {amount=f32(double(amount)/1000000.0f);format="%.2fm";}
    else if(compact && amount>=1000.0f) {amount=f32(double(amount)/1000.0f);format="%.1fk";}
    char buffer[32];std::snprintf(buffer,sizeof(buffer),format,double(amount));
    return String(buffer);
}

Vector2 SpiceNative::projected_random_vector(int64_t latitude_rand,int64_t angle_rand) {
    // getRandomVector0x110ab4 projects a sphere into XY. Its radius varies;
    // a unit circle changes the authored reward-burst distribution.
    // Explicit rand inputs preserve the math, not the original global stream.
    const float latitude=f32(double(f32(double(latitude_rand)))*0x1p-31f);
    const float z=f32(double(f32(double(latitude)+latitude))-1.0f);
    const float radius=std::sqrt(f32(1.0-double(f32(double(z)*z))));
    const float angle=f32(double(f32(double(f32(double(angle_rand)))*0x1p-31f))*6.2831854820251465f);
    const float theta=f32(double(angle)-3.1415927410125732f);
    return Vector2(f32(double(::cosf(theta))*radius),f32(double(::sinf(theta))*radius));
}

Dictionary SpiceNative::water_table(int64_t seed) {
    // CPerlin::Init0x11486c; a private Darwin-default Park-Miller stream.
    // The original seeds global libc rand. Whole-game call ordering is separate.
    int64_t state=seed;
    auto next=[&]() {if(state==0)state=123459876;state=(state*16807)%2147483647;return int(state);};
    PackedInt32Array permutation;PackedFloat32Array gradients;
    permutation.resize(1026);gradients.resize(1026);
    for(int i=0;i<1024;++i) {permutation[i]=i;gradients[i]=float(next()%2048-1024)*0.0009765625f;}
    for(int i=1023;i>0;--i) {const int j=next()%1024,p=permutation[i];permutation[i]=permutation[j];permutation[j]=p;}
    for(int i=0;i<2;++i) {permutation[1024+i]=permutation[i];gradients[1024+i]=gradients[i];}
    Dictionary result;result["permutation"]=permutation;result["gradients"]=gradients;return result;
}

namespace {
float water_noise_value(const PackedInt32Array &p,const PackedFloat32Array &g,float value) {
    // CPerlin::Noise0x114928, including rounding before integer truncation.
    const float shifted=value+4096.0f;
    const int whole=int(shifted);
    const float x=shifted-float(whole),minus_one=x-1.0f;
    const float smooth=(x*x)*(3.0f+x*-2.0f);
    const float a=x*g[p[whole&1023]],b=minus_one*g[p[(whole+1)&1023]];
    return a+smooth*(b-a);
}
}

double SpiceNative::water_noise(Dictionary table,double value) {
    const PackedInt32Array p=table["permutation"];const PackedFloat32Array g=table["gradients"];
    return water_noise_value(p,g,f32(value));
}

Dictionary SpiceNative::water_vertices(Dictionary table,Dictionary settings,double phase) {
    // CWater::Render0x95dd8. Geometry and each intermediate stay float32.
    const PackedInt32Array p=table["permutation"];const PackedFloat32Array g=table["gradients"];
    const Vector2 plane=settings.get("plane",Vector2(1024,1024)),segments=settings.get("segments",Vector2(15,28));
    const Array w=settings.get("water_uv",Array::make(0,1,0,1)),m=settings.get("mask_uv",Array::make(0,1,0,1));
    const float rows=segments.x,columns=segments.y,denominator=columns-2.0f;
    const float density=f32(double(settings.get("density",5))),mask_scale=f32(double(settings.get("mask_scale",0.5))),amplitude=f32(double(settings.get("amplitude",0.18)));
    const float horizontal_step=(float(plane.y)/denominator)*2.0f,vertical_step=float(plane.x)/rows;
    const float mask_u_span=((f32(double(m[1]))-f32(double(m[0])))*2.0f)*mask_scale;
    const float mask_v_span=(f32(double(m[3]))-f32(double(m[2])))*mask_scale;
    const float water_u_span=((f32(double(w[1]))-(f32(double(w[0]))+0.0010000000474974513f))*2.0f)*density;
    const float water_v_span=(f32(double(w[3]))-f32(double(w[2])))*density;
    const float s=std::sin(f32(phase)),c=std::cos(f32(phase));
    PackedVector2Array vertices,uvs,mask_uvs;
    if(rows>0 && columns>2) {
        for(int row=0;float(row)<rows;++row) {
            const float v0=f32(double(w[2]))+(float(row+1)*water_v_span)/rows;
            const float v1=f32(double(w[2]))+(float(row)*water_v_span)/rows;
            const float mv0=f32(double(m[2]))+(float(row+1)*mask_v_span)/rows;
            const float mv1=f32(double(m[2]))+(float(row)*mask_v_span)/rows;
            for(int column=0;float(column)<columns*0.5f;++column) {
                const float y_noise=water_noise_value(p,g,float(column)+s)*amplitude;
                const float x_noise=water_noise_value(p,g,float(column)-c)*amplitude;
                const float x=float(column)*horizontal_step;
                const float u=float(column)*(water_u_span/denominator)+x_noise;
                const float mu=float(column)*(mask_u_span/denominator);
                vertices.push_back(Vector2(x,float(row)*vertical_step+vertical_step));uvs.push_back(Vector2(u,v0+y_noise));mask_uvs.push_back(Vector2(mu,mv0));
                vertices.push_back(Vector2(x,float(row)*vertical_step));uvs.push_back(Vector2(u,v1+y_noise));mask_uvs.push_back(Vector2(mu,mv1));
            }
        }
    }
    const int count=int(rows*columns); // The native draw count, even for odd explicit inputs.
    if(vertices.size()>count) {vertices.resize(count);uvs.resize(count);mask_uvs.resize(count);}
    Dictionary result;result["vertices"]=vertices;result["uvs"]=uvs;result["mask_uvs"]=mask_uvs;return result;
}
bool SpiceNative::in_range(Vector2 a,Vector2 b,double radius,double hex_height) {
    return radius>0 && Ellipse(radius,hex_height).contains(a,b);
}
PackedInt32Array SpiceNative::range_candidates(Array entries,Vector2 position,double radius,double hex_height,int aim) {
    PackedInt32Array result;
    if(radius<=0)return result;
    const Ellipse ellipse(radius,hex_height);
    const Keys &k=keys();
    for(int i=0;i<entries.size();++i) {
        const Dictionary e=entries[i];
        if(double(e.get(k.hp,0))<=0)continue;
        const bool air=e.get(k.native_air,e.get(k.air,false));
        if(aim!=0 && ((aim==1 && air) || (aim==2 && !air)))continue;
        if(ellipse.contains(position,Vector2(e[k.pos])))result.append(i);
    }
    return result;
}
Dictionary SpiceNative::select_target(Array entries,Dictionary q,Callable grid) {
    const Keys &k=keys();
    const int aim=q.get("aim",0),owner=q.get("owner",1);
    const bool gravity=q.get("gravity",false),collect=q.get("collect",false),check_range=q.get("ellipse",false);
    const Vector2 cell=q.get("cell",Vector2());
    const Vector2 origin=q.get("origin",Vector2());
    const double radius=q.get("radius",1),hex_height=q.get("hex_height",1);
    const Ellipse ellipse(radius,hex_height);
    float nearest=100000000.0f;
    std::vector<int> candidates;
    for(int i=0;i<entries.size();++i) {
        const Dictionary e=entries[i];
        const int state=e.get(k.state,0);
        if(state==2 || state==3 || (gravity && state==5) || double(e.get(k.hp,10))<=0)continue;
        const int enemy_aim=e.get(k.aim,bool(e.get(k.native_air,e.get(k.air,false)))?2:1);
        if((aim!=0 && aim!=enemy_aim) || int(e.get(k.owner,0))==owner)continue;
        const int target_owner=e.get(k.target_owner,0);
        if(target_owner!=0 && target_owner!=owner)continue;
        Vector2 point;
        if(e.has(k.grid)) {
            const Array p=e[k.grid];point=Vector2(double(p[0]),double(p[1]));
        } else if(e.has(k.progress)) {
            const Vector2 start=Vector2(Vector2i(e[k.cell])),goal=Vector2(Vector2i(e[k.next_cell]));
            const double p=std::clamp(double(e[k.progress]),0.0,1.0);
            const float complement=f32(1.0-p);
            point=Vector2(f32(double(f32(double(start.x)*complement))+f32(double(goal.x)*p)),f32(double(f32(double(start.y)*complement))+f32(double(goal.y)*p)));
        } else point=grid.call(e);
        const float x=f32(double(point.x)-cell.x),y=f32(double(point.y)-cell.y);
        const float distance=f32(double(f32(double(x)*x))+f32(double(y)*y));
        if((!collect || gravity) && distance>=nearest)continue;
        if(check_range && (radius<=0 || !ellipse.contains(origin,Vector2(e[k.pos]))))continue;
        candidates.push_back(i);nearest=distance;
    }
    const String mode=q.get("mode","");
    const bool fastest=mode=="" || mode=="fastest",strongest=mode=="strongest",weakest=mode=="weakest";
    int best=-1;double threshold=weakest?100000000.0:0.0;
    Array collected;
    if(collect && !gravity)for(int i:candidates)collected.append(i);
    else for(int i:candidates) {
        const Dictionary e=entries[i];
        const float value=fastest?f32(double(e.get(k.speed,1000))*double(e.get(k.slow,1))):f32(double(e.get(k.hp,10)));
        if(((fastest || strongest) && value>threshold) || (weakest && value<threshold)) {
            best=i;threshold=strongest?double(int64_t(value)):double(value);
        }
    }
    Dictionary result;result["selected"]=best;result["collected"]=collected;return result;
}
Dictionary SpiceNative::movement_tick(Vector2 start,Vector2 target,Vector2 future,double progress,double carry_value,double speed,double dt,double hex_height) {
    float p=f32(progress),carry=f32(carry_value);
    const bool transitioned=p>=1.0f || start==target;
    if(transitioned) {start=target;target=future;p=carry;carry=0;}
    else {
        const float length=start.distance_to(target);
        const float factor=length!=0 ? f32(hex_height/length):1.0f;
        const float increment=f32(double(f32(double(f32(dt/1000.0))*f32(speed/1000.0)))*factor);
        p=f32(double(p)+increment);
        if(p>1) {p=1;carry=std::min(increment,f32(0.3));}
    }
    const Vector2 position(f32(double(start.x)+f32(double(f32(double(target.x)-start.x))*p)),f32(double(start.y)+f32(double(f32(double(target.y)-start.y))*p)));
    Dictionary result;result["progress"]=p;result["carry"]=carry;result["position"]=position;result["start"]=start;result["target"]=target;result["transitioned"]=transitioned;return result;
}
void SpiceNative::update_particle(Dictionary p,Dictionary d,double dt,double age) {
    ParticleCoefficients(d).integrate(p,dt,f32(age));
}
bool SpiceNative::advance_creep_fields(Dictionary actor,double dt_ms,int64_t remaining) {
    const Keys &k=keys();
    const float growth=f32(double(actor[k.grow_ms])+dt_ms);
    const Variant pending=actor[k.slow_pending];
    const bool consumed=double(pending)>0;
    const Variant slow=consumed?pending:Variant(1.0);
    const float speed=f32(double(actor[k.speed])*double(slow));
    // Validate before mutation so unusual inputs retain the script fallback.
    if(!std::isfinite(growth) || !std::isfinite(speed))return false;
    const bool attached=actor.get(k.freeze_attached,false);
    actor[k.grow_ms]=double(std::min(400.0f,growth));
    actor[k.slow]=slow;actor[k.consumed_slow]=consumed;actor[k.slow_pending]=-1.0;
    actor[k.animation_divisor]=speed!=0?double(f32(1000.0/double(speed))):std::numeric_limits<double>::infinity();
    // ProcessSpeed reads attachment before ProcessFreeze releases it on expiry.
    actor[k.animation_multiplier]=attached?0.0:1.0;
    actor[k.freeze_remaining]=attached?remaining:int64_t(0);
    if(attached && remaining<=0)actor[k.freeze_attached]=false;
    if(!(attached && remaining>0) && bool(actor.get(k.freeze_auxiliary_present,false)) && !consumed)actor[k.freeze_auxiliary_value]=int64_t(0);
    actor[k.poison_count]=int64_t(0);actor[k.slow_count]=int64_t(0);
    return true;
}
bool SpiceNative::frame_clock_advance(Dictionary state,double dt_ms) {
    const Keys &k=keys();
    const int64_t count=state[k.count];
    if(count<2) {state[k.frame]=0;state[k.stopped]=true;return true;}
    if(bool(state[k.stopped]))return true;
    // Separate float32 operations match CAnimProcessor::Update. No fused
    // arithmetic or remainder carry; keep script fallback for invalid clocks.
    const float rate=f32(double(f32(double(state[k.speed])/double(state[k.divisor])))*double(state[k.multiplier]));
    const float delta=f32(double(f32(double(f32(dt_ms))/1000.0))*rate);
    const float phase=f32(double(state[k.phase])+delta);
    if(!std::isfinite(phase) || double(phase)>=double(std::numeric_limits<int64_t>::max()) || double(phase)<double(std::numeric_limits<int64_t>::min()))return false;
    const int64_t frame=static_cast<int64_t>(phase);
    if(frame>=count) {
        const bool loop=state[k.loop];
        state[k.frame]=loop?0:count-1;state[k.stopped]=!loop;state[k.phase]=0.0;
    } else {state[k.phase]=double(phase);state[k.frame]=frame;}
    return true;
}
double SpiceNative::creep_light(double current,double target,double progress) {
    const float a=f32(current),b=f32(target);
    if(a==b)return a;
    const float value=f32(double(a)+f32(double(f32(double(b)-a))*f32(progress)));
    return a<b?std::min(value,b):std::max(value,b);
}

Vector2 SpiceNative::creep_missile_origin(Vector2 input,Vector2 target) {
    // Original Vector2Normalize uses reciprocal then multiplication.
    float x=f32(double(input.x)-target.x),y=f32(double(input.y)-target.y);
    const float length=std::sqrt(f32(double(f32(double(x)*x))+f32(double(y)*y)));
    if(length!=0) {
        const float inverse=f32(1.0/length);
        x=f32(double(x)*inverse);y=f32(double(y)*inverse);
    }
    return Vector2(f32(double(input.x)+f32(double(x)*-10)),f32(double(input.y)+f32(double(y)*-10)));
}

void SpiceNative::creep_missile_tick(Dictionary p,double dt,double raw_velocity) {
    // Nonimpact CCreepMissile::Update0x8120c: every operation rounds to
    // float32. Keep original zero-dt=>one-second quirk isolated here.
    Vector2 pos=p["pos"],target=p["destination"],velocity=p["velocity"],acceleration=p["acceleration"];
    p["previous"]=pos;
    float seconds=f32(double(std::min(f32(dt),100.0f))/1000);
    if(seconds==0)seconds=1;
    const float gamma=f32(double(f32(double(seconds)*3.75))/0.30000001192092896);
    const float speed=f32(double(f32(raw_velocity))*std::max(seconds,0.03999999910593033f));
    float dx=f32(double(target.x)-pos.x),dy=f32(double(target.y)-pos.y);
    const float length=std::sqrt(f32(double(f32(double(dx)*dx))+f32(double(dy)*dy)));
    if(length!=0) {
        const float inverse=f32(1.0/length);
        dx=f32(double(dx)*inverse);dy=f32(double(dy)*inverse);
    }
    const Vector2 goal(f32(double(dx)*speed),f32(double(dy)*speed));
    if(gamma>=1) {velocity=goal;acceleration=Vector2();}
    Vector2 next_velocity,next_acceleration;
    for(int axis=0;axis<2;++axis) {
        next_velocity[axis]=f32(double(velocity[axis])+f32(double(acceleration[axis])*gamma));
        const float delta=f32(double(goal[axis])-velocity[axis]);
        const float damping=axis==0?f32(double(acceleration[axis])*-2):f32(double(acceleration[axis])+acceleration[axis]);
        const float change=axis==0?f32(double(delta)+damping):f32(double(delta)-damping);
        next_acceleration[axis]=f32(double(acceleration[axis])+f32(double(change)*gamma));
        pos[axis]=f32(double(pos[axis])+f32(double(next_velocity[axis])*seconds));
    }
    p["velocity"]=next_velocity;p["acceleration"]=next_acceleration;p["pos"]=pos;
    if(bool(p.get("body_flag",false))) {
        const Vector2 start=p.get("start",p["previous"]);
        const float x=f32(double(start.x)-pos.x),y=f32(double(start.y)-pos.y);
        if(std::sqrt(f32(double(f32(double(x)*x))+f32(double(y)*y)))>30)p["body_flag"]=false;
    }
}

double SpiceNative::creep_depth(double center_y,double height) {
    // CCreep UpdatePosition0x7d108 then CMap comparator0x103650.
    // Current map positions/heights stay within the original signed-int range.
    const float h=f32(height);
    const int32_t top=static_cast<int32_t>(f32(double(f32(center_y))+f32(double(h)*-0.5)));
    return f32(double(f32(top))+h);
}
void SpiceNative::update_particles(Array particles,Dictionary d,double dt,double clock_ms) {
    integrate_particles(particles,ParticleCoefficients(d),dt,clock_ms);
}
int64_t SpiceNative::compile_particle(Dictionary d) {
    const String signature=String(d.get("source_sha256",""))+":"+String(d.get("name",""));
    const std::string key=signature.utf8().get_data();
    auto found=particle_ids.find(key);if(found!=particle_ids.end())return found->second;
    const int64_t index=compiled_particles.size();compiled_particles.emplace_back(d);particle_ids.emplace(key,index);return index;
}
void SpiceNative::advance_systems(Array systems,double clock_ms,Callable emit_child,Callable emit_batch,RandomNumberGenerator *random,double dt) {
    const Keys &k=keys();
    dt=f32(dt);
    const int count=systems.size();
    std::unordered_set<int64_t> expired;
    for(int i=0;i<count;++i) {
        Dictionary sys=systems[i];
        double system_clock=clock_ms;
        if(sys.has(k.local_clock_seconds)) {
            const float seconds=f32(double(sys[k.local_clock_seconds])+dt);
            sys[k.local_clock_seconds]=double(seconds);
            system_clock=double(seconds)*1000.0;sys[k.view_clock_ms]=system_clock;
        }
        const Dictionary d=sys[k.definition];
        const int64_t token=sys.get(k.coefficients,-1);
        const CompiledParticle compiled=token>=0 && token<int64_t(compiled_particles.size()) ? compiled_particles[token] : CompiledParticle(d);
        const double until=sys[k.until];
        if(until>=0 && system_clock>=until)sys[k.emitting]=false;
        const int64_t disable=compiled.disable;
        if(disable>0 && system_clock-double(sys[k.born])>=disable)sys[k.emitting]=false;
        Array particles=sys[k.particles];
        integrate_particles(particles,compiled.particle,dt,system_clock);
        const double amplitude=compiled.amplitude;
        const String child=compiled.child;
        if(amplitude!=0 || !child.is_empty())for(int j=0;j<particles.size();++j) {
            Dictionary p=particles[j];
            if(amplitude!=0) {
                const double old=sys[k.phase];
                const float phase=f32(old+f32(compiled.amplification_speed*dt));
                sys[k.phase]=phase;
                Vector2 position=p[k.pos];
                position.x=f32(double(position.x)+f32(double(f32(std::sin(double(phase))-std::sin(old)))*amplitude));
                p[k.pos]=position;
            }
            if(!child.is_empty() && system_clock-double(p[k.child_released])>50) {
                p[k.child_released]=system_clock;
                emit_child.call(child,p[k.pos],sys[k.variation]);
            }
        }
        if(bool(sys[k.emitting]) && dt<compiled.particle.life && double(system_clock-double(sys[k.released]))>compiled.interval*1000.0) {
            if(particles.size()>=int(d.get("max_particles",100)))sys[k.released]=system_clock;
            else if(random)SpiceNative::emit_batch(sys,system_clock,random);
            else emit_batch.call(sys);
        }
        if(!bool(sys[k.emitting]) && particles.is_empty())expired.insert(int64_t(sys[k.id]));
    }
    if(!expired.empty()) {
        int live=0;
        for(int i=0;i<systems.size();++i) {
            const Dictionary sys=systems[i];
            if(expired.count(int64_t(sys[k.id])))continue;
            if(live!=i)systems[live]=sys;
            ++live;
        }
        systems.resize(live);
    }
}
void SpiceNative::emit_batch(Dictionary sys,double clock_ms,RandomNumberGenerator *random) {
    const Keys &k=keys();
    const Dictionary d=sys[k.definition];
    Array particles=sys[k.particles];
    const int number=d.get("num_release",1),maximum=d.get("max_particles",100);
    Object *texture_object=sys[k.texture];
    Texture2D *texture=Object::cast_to<Texture2D>(texture_object);
    if(!random || !texture)return;
    const Array rectangles=d["texture_list"];
    const Array velocity_values=d.get("velocity",Array::make(0,0));
    constexpr double tau=6.28318530717958647692,deg_to_rad=0.01745329251994329577;
    for(int i=0;i<number;++i) {
        if(particles.size()>=maximum)break;
        Dictionary rect;
        if(!rectangles.is_empty())rect=rectangles[random->randi_range(0,rectangles.size()-1)];
        else {
            rect["x"]=d.get("tx",0);rect["y"]=d.get("ty",0);
            rect["w"]=d.get("tw",texture->get_width());rect["h"]=d.get("th",texture->get_height());
        }
        const Rect2 region{f32(double(rect["x"])),f32(double(rect["y"])),f32(double(rect["w"])),f32(double(rect["h"]))};
        Vector2 velocity{f32(double(velocity_values[0])),f32(double(velocity_values[1]))};
        Vector2 point=sys[k.pos];
        if(int(d.get("circled_emission",0))) {
            const double angle=tau*i/std::max(1,number)+random->randf_range(-double(d.get("circle_angle_var",0)),double(d.get("circle_angle_var",0)))*deg_to_rad;
            const Vector2 heading(std::cos(angle),std::sin(angle));
            point+=heading*f32(double(d.get("circle_radius",0)));
            velocity=heading*f32(double(d.get("circle_vel_amount",0))+random->randf_range(0,double(d.get("velocity_var",1))));
        } else velocity+=Vector2::from_angle(f32(random->randf()*tau))*f32(double(d.get("velocity_var",1)));
        double rot_speed=d.get("rot_speed",1.0);
        if(random->randi_range(0,99)<int(d.get("rot_dir_rand",0)))rot_speed*=random->randi()%2?1:-1;
        double rotation=d.get("rot_angle",0);
        const double rot_variation=d.get("rot_angle_var",0);
        rotation+=random->randf_range(-rot_variation/2,rot_variation/2);
        const double size_variation=d.get("size_init_var",0);
        const double size_offset=random->randf_range(-size_variation,size_variation);
        Dictionary p;
        p[k.pos]=point;p[k.velocity]=velocity;p[k.rotation]=rotation;p[k.rot_speed]=rot_speed;
        p[k.alpha]=double(d.get("fade_in_time",0))>0?0.0:1.0;p[k.born]=clock_ms;
        p["region"]=region;p["size_offset"]=size_offset;p[k.child_released]=clock_ms;
        particles.push_front(p);
    }
    sys[k.released]=clock_ms;
}
Array SpiceNative::particle_batches(Array systems,bool premultiplied,double clock_ms,Vector2 origin,double zoom,bool mesh_color_quantization,bool reference_keys) {
    const Keys &k=keys();
    // Keep the former text-key path selectable for exact geometry/CPU checks.
    // Lookup/output keys and immutable white default are reused. Output keys
    // retain String type; geometry serialization remains byte-exact.
    const auto lookup=[reference_keys](const char *text,const StringName &name)->Variant {return reference_keys?Variant(text):Variant(name);};
    const auto output_key=[reference_keys](const char *text,const Variant &key)->Variant {return reference_keys?Variant(text):key;};
    static const Array white=Array::make(1,1,1,1);
    Array result;Texture2D *previous=nullptr;Variant current_texture;
    std::vector<Vector2> vertex_data,uv_data;std::vector<Color> color_data;std::vector<int32_t> index_data;
    auto flush=[&]() {
        if(vertex_data.empty())return;
        PackedVector2Array vertices,uvs;PackedColorArray colors;PackedInt32Array indices;
        vertices.resize(vertex_data.size());uvs.resize(uv_data.size());colors.resize(color_data.size());indices.resize(index_data.size());
        std::copy(vertex_data.begin(),vertex_data.end(),vertices.ptrw());std::copy(uv_data.begin(),uv_data.end(),uvs.ptrw());std::copy(color_data.begin(),color_data.end(),colors.ptrw());std::copy(index_data.begin(),index_data.end(),indices.ptrw());
        Dictionary group;group[output_key("texture",k.output_texture)]=current_texture;group[output_key("vertices",k.output_vertices)]=vertices;group[output_key("uvs",k.output_uvs)]=uvs;group[output_key("colors",k.output_colors)]=colors;group[output_key("indices",k.output_indices)]=indices;result.append(group);
        vertex_data.clear();uv_data.clear();color_data.clear();index_data.clear();
    };
    for(int si=0;si<systems.size();++si) {
        const Dictionary sys=systems[si],d=sys[k.definition];
        if(bool(sys.get(k.owner_hidden,false)))continue;
        // Lobby cloud systems advance at separate caller-supplied clock
        // ratios. Keep their age while batching the shared texture in order.
        const double view_clock=sys.get(lookup("view_clock_ms",k.view_clock_ms),clock_ms);
        if((int(d.get(lookup("real_alpha",k.real_alpha),0))==1)!=premultiplied)continue;
        const Array rgba=d.get(lookup("color",k.color),(reference_keys?Array::make(1,1,1,1):white)),particles=sys[k.particles];
        Object *object=sys[k.texture];Texture2D *texture=Object::cast_to<Texture2D>(object);
        if(!texture)continue;
        const float tw=texture->get_width(),th=texture->get_height();
        const double base_size=d.get(lookup("size",k.size),1),raw_life=d.get(lookup("life_cycle",k.life_cycle),1);
        const float scale=f32(double(d.get(lookup("scale",k.scale),0)));
        const bool scalable=int(d.get(lookup("scalable",k.scalable),0))!=0,real_size=int(d.get(lookup("use_real_size",k.use_real_size),0))!=0,rotational=int(d.get(lookup("rotational",k.rotational),0))!=0;
        for(int pi=0;pi<particles.size();++pi) {
            const Dictionary p=particles[pi];const Rect2 region=p[lookup("region",k.region)];
            const float age=f32(double(f32(view_clock/1000.0))-f32(double(p[k.born])/1000.0));
            float factor=1;
            if(scalable) {
                const float progress=f32(double(age)/raw_life);
                factor=scale<=1?f32(1.0-double(f32(double(f32(1.0-double(scale)))*progress))):f32(1.0+double(f32(double(scale)*progress)));
            }
            const float half=f32((base_size+double(p[lookup("size_offset",k.size_offset)]))*factor);
            const Vector2 shape=real_size?region.size*half:Vector2(half,half)*2.0f;
            const double alpha=p[k.alpha];
            Color tint(f32(double(rgba[0])),f32(double(rgba[1])),f32(double(rgba[2])),f32(double(rgba[3])*std::max(0.0,alpha)));
            if(premultiplied) {tint.r=f32(double(tint.r)*alpha);tint.g=f32(double(tint.g)*alpha);tint.b=f32(double(tint.b)*alpha);}
            const double raw_rotation=rotational?double(p[k.rotation])+1.57079632679489661923:0;
            const float rotation=f32(raw_rotation),z=f32(zoom);
            const Vector2 center=origin+Vector2(p[k.pos])*z;
            if(region.position.x<0 || region.position.y<0 || region.get_end().x>tw || region.get_end().y>th || region.size.x<=0 || region.size.y<=0) {
                flush();Dictionary fallback;fallback[output_key("fallback",k.output_fallback)]=true;fallback[output_key("texture",k.output_texture)]=sys[k.texture];fallback[output_key("region",k.output_region)]=region;fallback[output_key("center",k.output_center)]=center;fallback[output_key("shape",k.output_shape)]=shape;fallback[output_key("rotation",k.output_rotation)]=raw_rotation;fallback[output_key("tint",k.output_tint)]=tint;result.append(fallback);previous=nullptr;continue;
            }
            if(mesh_color_quantization) {
                // ArrayMesh upload clamps/truncates to RGBA8. Preserve that
                // contract for direct canvas triangles, once per particle.
                // The rect-region fallback above keeps its original raw tint.
                auto channel=[](float value) {return f32(double(uint8_t(std::clamp(double(value)*255.0,0.0,255.0)))/255.0);};
                tint=Color(channel(tint.r),channel(tint.g),channel(tint.b),channel(tint.a));
            }
            if(previous!=texture) {
                flush();current_texture=sys[k.texture];previous=texture;
            }
            const int at=vertex_data.size();const float c=std::cos(rotation)*z,s=std::sin(rotation)*z;
            const Vector2 corners[4]={-shape/2.0f,Vector2(shape.x/2.0f,-shape.y/2.0f),shape/2.0f,Vector2(-shape.x/2.0f,shape.y/2.0f)};
            const Vector2 uv[4]={region.position/Vector2(tw,th),Vector2(region.get_end().x/tw,region.position.y/th),region.get_end()/Vector2(tw,th),Vector2(region.position.x/tw,region.get_end().y/th)};
            for(int j=0;j<4;++j) {const Vector2 v=corners[j];vertex_data.push_back(center+Vector2(c*v.x-s*v.y,s*v.x+c*v.y));uv_data.push_back(uv[j]);color_data.push_back(tint);}
            for(int j:{0,1,2,0,2,3})index_data.push_back(at+j);
        }
    }
    flush();return result;
}
Dictionary SpiceNative::bolt_ribbon(PackedVector2Array path,int64_t pass_id,double opacity) {
    const int count=path.size()-1,divisor=count-1;
    PackedVector2Array vertices,uvs;PackedColorArray colors;PackedInt32Array indices;
    Rect2 bounds;
    if(count>=2) {
        const int size=4*divisor+4;
        vertices.resize(size);uvs.resize(size);colors.resize(size);indices.resize((size-2)*3);
        Vector2 *v=vertices.ptrw(),*uv=uvs.ptrw();Color *c=colors.ptrw();int32_t *ix=indices.ptrw();
        const float intensity=pass_id==1?1.0f:f32(double(int(opacity*255.0*0.25))/255.0);
        const float alpha=pass_id==1?f32(opacity):intensity;
        const Color cap=pass_id==1?Color(1,1,1,0):Color(0,0,0,0),ink(intensity,intensity,intensity,alpha);
        int width=(count+1)*(pass_id==1?12:24)/divisor;
        Vector2 normal=-(path[1]-path[0]).normalized().orthogonal();
        v[0]=path[0]+normal*width;v[1]=path[0]-normal*width;
        uv[0]=Vector2(0,0);uv[1]=Vector2(1,0);c[0]=c[1]=cap;
        int at=2;
        for(int i=0;i<divisor;++i) {
            width=(count+1-i)*(pass_id==1?12:24)/divisor;
            const Vector2 incoming=(path[i+1]-path[i]).normalized(),outgoing=(path[i+2]-path[i+1]).normalized();
            normal=-((incoming+outgoing)*0.5f).normalized().orthogonal();
            const Vector2 a=path[i+1]+normal*width,b=path[i+1]-normal*width;
            v[at]=v[at+2]=a;v[at+1]=v[at+3]=b;
            uv[at]=Vector2(0,1);uv[at+1]=Vector2(1,1);uv[at+2]=Vector2(0,0);uv[at+3]=Vector2(1,0);
            for(int j=0;j<4;++j)c[at+j]=ink;
            at+=4;
        }
        normal=-(path[count]-path[count-1]).normalized().orthogonal();
        v[at]=path[count]+normal*width;v[at+1]=path[count]-normal*width;
        uv[at]=Vector2(0,1);uv[at+1]=Vector2(1,1);c[at]=c[at+1]=cap;
        bounds=Rect2(v[0],Vector2());
        for(int i=0;i<size;++i)bounds.expand_to(v[i]);
        for(int i=0;i<size-2;++i) {
            ix[i*3]=i%2?i+1:i;ix[i*3+1]=i%2?i:i+1;ix[i*3+2]=i+2;
        }
    }
    Dictionary result;result["vertices"]=vertices;result["uvs"]=uvs;result["colors"]=colors;result["indices"]=indices;result["bounds"]=bounds;return result;
}
static void initialize_spice(ModuleInitializationLevel level) {
    if(level==MODULE_INITIALIZATION_LEVEL_SCENE)GDREGISTER_CLASS(SpiceNative);
}
extern "C" GDExtensionBool GDE_EXPORT spice_hotpaths_init(GDExtensionInterfaceGetProcAddress get_proc,const GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc,library,initialization);
    init.register_initializer(initialize_spice);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
