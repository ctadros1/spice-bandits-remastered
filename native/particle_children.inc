// Owned particle lifecycle and recursive geometry. Compiled with hotpaths.cpp;
// uses its explicit float32 arithmetic and unchanged particle coefficients.
namespace {
int64_t child_bits(float x) { uint32_t u;std::memcpy(&u,&x,sizeof u);return u; }
Vector2 child_point(const Variant &v) {if(v.get_type()==Variant::VECTOR2)return v;const Array a=v;return Vector2(f32(double(a[0])),f32(double(a[1])));}
uint8_t child_channel(double x) {
    const float scaled=f32(double(f32(x))*255.0);
    if(std::isnan(scaled))return 0;
    if(scaled<=-2147483648.0)return 0;
    if(scaled>=2147483647.0)return 255;
    return uint8_t(int32_t(scaled));
}
struct ChildQuad { Vector2 position[4],uv[4];uint8_t rgba[4]; };
struct ChildRenderKeys {
    const StringName clock{"clock_seconds"},born{"born_seconds"},size_var{"size_init_var"},orient{"orient_to_velocity"},angle{"direction_angle"},width{"width"},height{"height"},uv{"uv"},rgba{"rgba"},child{"child"};
};
const ChildRenderKeys &child_keys() {static const ChildRenderKeys value;return value;}
struct ChildAppearance {
    float size,clock=0,life=1,scale=0;
    bool size_var,scalable,real_size,rotates,real_alpha;
    explicit ChildAppearance(const Dictionary &system) {
        const Keys &k=keys();const auto &ck=child_keys();const Dictionary d=system[k.definition];
        size=f32(double(d.get(k.size,1)));size_var=double(d.get(ck.size_var,0))!=0;
        scalable=d.get(k.scalable,false);real_size=d.get(k.use_real_size,false);real_alpha=d.get(k.real_alpha,false);
        rotates=bool(d.get(k.rotational,false))||bool(d.get(ck.orient,false));
        if(scalable) {clock=f32(double(system[ck.clock]));life=f32(double(d.get(k.life_cycle,1)));scale=f32(double(d.get(k.scale,0)));}
    }
};
ChildQuad child_quad(bool root_rotation,const ChildAppearance &a,const Dictionary &p) {
    const Keys &k=keys();const auto &ck=child_keys();const Dictionary t=p[k.texture];const float size=a.size;
    float half=a.size_var?f32(double(size)+f32(double(p.get(k.size_offset,0)))):size;
    float factor=1;
    if(a.scalable) {
        const float age=f32(double(a.clock)-f32(double(p.get(ck.born,0))));
        const float progress=f32(double(age)/a.life),scale=a.scale;
        factor=scale<=1?f32(1.0-double(f32(double(f32(1.0-double(scale)))*progress))):f32(1.0+double(f32(double(scale)*progress)));
        half=f32(double(half)*factor);
    }
    float w=half,h=half;
    if(a.real_size) {
        w=f32(double(f32(double(t[ck.width])*0.5))*size);h=f32(double(f32(double(t[ck.height])*0.5))*size);
        if(a.scalable) {w=f32(double(w)*factor);h=f32(double(h)*factor);}
    }
    const Vector2 position=child_point(p[k.pos]);const float x=position.x,y=position.y;
    ChildQuad q;
    if(!a.rotates) {
        q.position[0]=Vector2(f32(double(x)-w),f32(double(y)-h));q.position[1]=Vector2(f32(double(x)+w),f32(double(y)-h));
        q.position[2]=Vector2(f32(double(x)-w),f32(double(y)+h));q.position[3]=Vector2(f32(double(x)+w),f32(double(y)+h));
    } else {
        float angle=root_rotation?f32(double(p.get(k.rotation,0))):f32(double(p.get(ck.angle,0)));
        angle=f32(double(angle)+f32(1.57079632679489661923));
        const float c=f32(std::cos(double(angle))),s=f32(std::sin(double(angle)));
        const float wc=f32(double(w)*c),hs=f32(double(h)*s),hc=f32(double(h)*c),ws=f32(double(w)*s);
        q.position[0]=Vector2(f32(double(f32(double(-wc)-(-hs)))+x),f32(double(f32(double(-hc)+(-ws)))+y));
        q.position[1]=Vector2(f32(double(f32(double(wc)-(-hs)))+x),f32(double(f32(double(-hc)+ws))+y));
        q.position[2]=Vector2(f32(double(f32(double(-wc)-hs))+x),f32(double(f32(double(hc)+(-ws)))+y));
        q.position[3]=Vector2(f32(double(f32(double(wc)-hs))+x),f32(double(f32(double(hc)+ws))+y));
    }
    const Array uv=t[ck.uv],rgba=p[ck.rgba];
    q.uv[0]=Vector2(f32(double(uv[0])),f32(double(uv[2])));q.uv[1]=Vector2(f32(double(uv[1])),f32(double(uv[2])));
    q.uv[2]=Vector2(f32(double(uv[0])),f32(double(uv[3])));q.uv[3]=Vector2(f32(double(uv[1])),f32(double(uv[3])));
    for(int i=0;i<4;++i)q.rgba[i]=child_channel(double(rgba[i]));
    return q;
}
template<class Sink>void child_visit(bool root_rotation,const ChildAppearance &appearance,const Dictionary &p,Sink &sink) {
    const Keys &k=keys();const auto &ck=child_keys();sink(child_quad(root_rotation,appearance,p));
    const Dictionary child=p.get(ck.child,Dictionary());if(child.is_empty())return;
    const ChildAppearance child_appearance(child);const Array particles=child[k.particles];const double opacity=p[k.alpha];
    for(int i=0;i<particles.size();++i) {
        const Dictionary cp=particles[i];Array rgba=cp[ck.rgba];
        if(child_appearance.real_alpha)for(int j=0;j<3;++j)rgba[j]=double(f32(double(rgba[j])*opacity));
        rgba[3]=double(f32(double(rgba[3])*opacity));child_visit(root_rotation,child_appearance,cp,sink);
    }
}
template<class Sink>void child_visit_root(const Dictionary &root,Sink &sink) {
    const Keys &k=keys();const ChildAppearance appearance(root);const Dictionary d=root[k.definition];const bool rotates=d.get(k.rotational,false);
    const Array particles=root[k.particles];for(int i=0;i<particles.size();++i)child_visit(rotates,appearance,Dictionary(particles[i]),sink);
}
}
namespace {
// Cache String Variants, preserving existing dictionary key types and order.
// This removes repeated UTF-8 key construction without changing field math.
struct OwnedUpdateKeys {
    const Variant advance_calls{String("advance_calls")};
    const Variant alpha{String("alpha")};
    const Variant amplification_speed{String("amplification_speed")};
    const Variant amplifyX_withSin_by{String("amplifyX_withSin_by")};
    const Variant born_seconds{String("born_seconds")};
    const Variant child{String("child")};
    const Variant child_system{String("child_system")};
    const Variant clock_seconds{String("clock_seconds")};
    const Variant color{String("color")};
    const Variant definition{String("definition")};
    const Variant delay_seconds{String("delay_seconds")};
    const Variant disable_after{String("disable_after")};
    const Variant fade_in_time{String("fade_in_time")};
    const Variant first_release{String("first_release")};
    const Variant interval_seconds{String("interval_seconds")};
    const Variant life_cycle{String("life_cycle")};
    const Variant max_particles{String("max_particles")};
    const Variant motion_limited{String("motion_limited")};
    const Variant motion_seconds{String("motion_seconds")};
    const Variant native_coefficients{String("native_coefficients")};
    const Variant particles{String("particles")};
    const Variant phase{String("phase")};
    const Variant pool{String("pool")};
    const Variant pos{String("pos")};
    const Variant rate{String("rate")};
    const Variant real_alpha{String("real_alpha")};
    const Variant release_interval{String("release_interval")};
    const Variant release_seconds{String("release_seconds")};
    const Variant rgba{String("rgba")};
    const Variant rot_speed{String("rot_speed")};
    const Variant rotation{String("rotation")};
    const Variant time_scale{String("time_scale")};
    const Variant wind_enabled{String("wind_enabled")};
};
const OwnedUpdateKeys &owned_update_keys() {static const OwnedUpdateKeys value;return value;}
}
void SpiceNative::owned_particle_emit(Dictionary system,int64_t count,Callable make_particle,Callable make_child) {
    const auto &k=owned_update_keys();
    system[k.release_seconds]=system[k.clock_seconds];
    Array particles=system[k.particles],pool=system[k.pool];const Dictionary d=system[k.definition];
    for(int64_t i=0;i<count;++i) {
        if(particles.size()>=int64_t(d.get(k.max_particles,100)))continue;
        const bool fresh=pool.is_empty();Dictionary p=fresh?Dictionary():Dictionary(pool.pop_front());
        const Dictionary old_child=p.get(k.child,Dictionary());const Dictionary values=make_particle.call(system,i,fresh,p);p.merge(values,true);
        if(fresh) {
            const String name=d.get(k.child_system,"");p[k.child]=name.is_empty()?Variant(Dictionary()):make_child.call(name);
        } else p[k.child]=old_child;
        p[k.born_seconds]=system[k.clock_seconds];
        const double opacity=double(d.get(k.fade_in_time,0))>0?0:1;p[k.alpha]=opacity;
        const Array color=d.get(k.color,Array::make(1,1,1,1));Array rgba;
        for(int j=0;j<4;++j) {const float value=f32(double(color[j]));rgba.append(double(j==3||bool(d.get(k.real_alpha,false))?f32(double(value)*opacity):value));}
        p[k.rgba]=rgba;particles.push_front(p);system[k.first_release]=false;
    }
}
void SpiceNative::owned_particle_advance(Dictionary system,double input_dt,Callable make_particle,Callable make_child,double interval_scale,bool prepared) {
    const auto &k=owned_update_keys();
    const float dt=f32(input_dt);system[k.advance_calls]=int64_t(system.get(k.advance_calls,0))+1;
    const double delay=system[k.delay_seconds];
    if(delay>0) {system[k.delay_seconds]=double(f32(delay-dt));return;}
    const Dictionary d=system[k.definition];
    const float clock=f32(double(system[k.clock_seconds])+f32(double(f32(double(d.get(k.time_scale,1))))*dt));system[k.clock_seconds]=double(clock);
    const float disable=f32(double(d.get(k.disable_after,0))/1000.0);
    if(disable>0 && disable<=clock && !bool(system[k.first_release]))system[k.rate]=0;
    // Empty owned roots still run their clock and Emit(0) release phases.
    // They have no particle physics, color, child or phase work to perform.
    const Array particles=system[k.particles];
    if(particles.is_empty()) {
        const float life=f32(double(d.get(k.life_cycle,1)));
        const float interval=f32(double(f32(double(system.get(k.interval_seconds,d.get(k.release_interval,1)))))*f32(interval_scale));
        if(interval<f32(double(clock)-double(system[k.release_seconds]))&&dt<life)owned_particle_emit(system,int64_t(system[k.rate]),make_particle,make_child);
        return;
    }
    // Headers are immutable after construction. Keep the reconstruct/copy
    // path selectable for exact state and controlled CPU comparisons.
    ParticleCoefficients coefficients=[&]() {
        if(!prepared) {Dictionary physics=d.duplicate();physics[k.wind_enabled]=system[k.wind_enabled];return ParticleCoefficients(physics);}
        const int64_t token=system.get(k.native_coefficients,-1);
        if(token>=0 && token<int64_t(compiled_particles.size()))return compiled_particles[token].particle;
        return ParticleCoefficients(d);
    }();
    coefficients.wind_enabled=bool(system[k.wind_enabled]);
    const float life=f32(double(d.get(k.life_cycle,1)));const Array color=d.get(k.color,Array::make(1,1,1,1));Array live,pool=system[k.pool];
    const bool limited=system.get(k.motion_limited,false);const double motion=system.get(k.motion_seconds,0);
    // Imported definitions are immutable. Reuse only within this update call.
    const bool real_alpha=d.get(k.real_alpha,false);const float amplitude=f32(double(d.get(k.amplifyX_withSin_by,0)));
    const double amplification_speed=d.get(k.amplification_speed,0);
    float color_values[4];for(int j=0;j<4;++j)color_values[j]=f32(double(color[j]));
    for(int i=0;i<particles.size();++i) {
        Dictionary p=particles[i];const float age=f32(double(clock)-double(p[k.born_seconds]));
        const bool active=age<life,moving=!limited||age<motion;
        if(active&&moving)coefficients.integrate(p,dt,age);
        else {p[k.rotation]=double(f32(double(p[k.rotation])+f32(double(p[k.rot_speed])*dt)));p[k.alpha]=double(coefficients.opacity(age));}
        const double opacity=p[k.alpha];Array rgba=p[k.rgba];
        if(real_alpha)for(int j=0;j<3;++j)rgba[j]=double(f32(double(color_values[j])*opacity));
        rgba[3]=double(f32(double(color_values[3])*opacity));
        if(active) {
            live.append(p);Dictionary child=p.get(k.child,Dictionary());
            if(moving&&!child.is_empty()) {child[k.pos]=p[k.pos];owned_particle_advance(child,dt,make_particle,make_child,interval_scale,prepared);}
        } else pool.push_front(p);
        if(amplitude!=0) {
            const double old=system.get(k.phase,0);const float phase=f32(old+f32(amplification_speed*dt));system[k.phase]=double(phase);
            Vector2 position=p[k.pos];position.x=f32(double(position.x)+f32(double(f32(std::sin(double(phase))-std::sin(old)))*amplitude));p[k.pos]=position;
        }
    }
    system[k.particles]=live;
    const float interval=f32(double(f32(double(system.get(k.interval_seconds,d.get(k.release_interval,1)))))*f32(interval_scale));
    if(interval<f32(double(clock)-double(system[k.release_seconds]))&&dt<life)owned_particle_emit(system,int64_t(system[k.rate]),make_particle,make_child);
}
void SpiceNative::owned_particle_restart(Dictionary system) {
    const Array particles=system["particles"];Array pool=system["pool"];
    for(int i=0;i<particles.size();++i)pool.push_front(particles[i]);system["particles"]=Array();
}
void SpiceNative::owned_particle_destroy(Dictionary system,Array deleted) {
    for(const char *name:{"particles","pool"}) {
        const Array particles=system[name];
        for(int i=0;i<particles.size();++i) {const Dictionary p=particles[i];Dictionary child=p.get("child",Dictionary());
            if(!child.is_empty()) {owned_particle_destroy(child,deleted);deleted.append(child.get("id",0));}deleted.append(p.get("id",0));}
        system[name]=Array();
    }
}
Dictionary SpiceNative::owned_particle_render(Dictionary root,bool homogeneous) {
    Array vertices;
    auto sink=[&](const ChildQuad &q) {
        const bool first=vertices.is_empty();const int order[6]={0,0,1,2,3,3};const Array rgba=Array::make(q.rgba[0],q.rgba[1],q.rgba[2],q.rgba[3]);
        for(int i=first?1:0;i<6;++i) {const int at=order[i];Dictionary v;v["position_bits"]=Array::make(child_bits(q.position[at].x),child_bits(q.position[at].y));v["uv_bits"]=homogeneous?Variant():Variant(Array::make(child_bits(q.uv[at].x),child_bits(q.uv[at].y)));v["rgba8"]=rgba.duplicate();vertices.append(v);}
    };
    child_visit_root(root,sink);Dictionary result;result["count"]=vertices.size();result["vertices"]=vertices;return result;
}
Array SpiceNative::owned_particle_batches(Dictionary root,Vector2 origin,double zoom) {
    PackedVector2Array vertices,uvs;PackedColorArray colors;PackedInt32Array indices;const float z=f32(zoom);
    auto sink=[&](const ChildQuad &q) {
        const int at=vertices.size();const Color tint(f32(double(q.rgba[0])/255),f32(double(q.rgba[1])/255),f32(double(q.rgba[2])/255),f32(double(q.rgba[3])/255));
        for(int j=0;j<4;++j) {vertices.append(origin+q.position[j]*z);uvs.append(q.uv[j]);colors.append(tint);}
        // Original nondegenerate strip triangles: TL/TR/BL, BL/TR/BR.
        for(int j:{0,1,2,2,1,3})indices.append(at+j);
    };
    child_visit_root(root,sink);Array groups;
    if(!vertices.is_empty()) {Dictionary g;g["texture"]=root["texture"];g["vertices"]=vertices;g["uvs"]=uvs;g["colors"]=colors;g["indices"]=indices;groups.append(g);}return groups;
}
