
shader_type spatial;
// render_mode unshaded;

uniform sampler2D cubemap_albedo : source_color, repeat_disable;
uniform sampler2D cubemap_normalmap : hint_normal, repeat_disable;
uniform sampler2D cubemap_emission : hint_default_black, repeat_disable;

uniform float room_width : hint_range(0.1, 8.0, 0.01) = 2.0;
uniform float room_length : hint_range(0.1, 20.0, 0.01) = 2.0;
uniform float room_depth : hint_range(0.1, 8.0, 0.01) = 1.0;
uniform float floor_offset : hint_range(-10.0, 10.0, 0.01) = 0.0;

uniform float emission_strength : hint_range(0.0, 10.0, 0.01) = 0.0;

// Additional inset within each cubemap face. A half-texel
// minimum is always applied to avoid atlas bleeding.
uniform float atlas_inset : hint_range(0.0, 0.05, 0.001) = 0;

varying vec3 obj_vertex;
varying vec3 obj_cam;


float remap_range(
    float value,
    float min_in,
    float max_in,
    float min_out,
    float max_out
) {
    return (value - min_in) / (max_in - min_in)
        * (max_out - min_out) + min_out;
}


// Prevent division by values close to zero.
float safe_div(float a, float b) {
    float epsilon = 0.0001;

    if (abs(b) < epsilon) {
        b = (b < 0.0) ? -epsilon : epsilon;
    }

    return a / b;
}


// Sample one face from the 3x2 cubemap atlas.
vec3 sample_cubemap(sampler2D cubemap, vec2 uv, vec3 face) {
    face = normalize(face);

    // Keep coordinates inside the individual face. Clamp at
    // least half a texel away from the cell borders so
    // filtering never bleeds into neighboring atlas cells.
    vec2 texel = 1.0 / vec2(textureSize(cubemap, 0));
    vec2 min_inset = texel * vec2(3.0, 2.0) * 0.5;
    vec2 inset = max(vec2(atlas_inset), min_inset);

    vec2 p = clamp(uv, inset, vec2(1.0) - inset);

    // Vertical orientation correction.
    p.y = 1.0 - p.y;

    // +X: top-left.
    if (face.x == 1.0) {
        p.x = p.x / 3.0;
        p.y = p.y / 2.0;
    }
    // -X: bottom-left.
    else if (face.x == -1.0) {
        p.x = p.x / 3.0;
        p.y = 0.5 + p.y / 2.0;
    }
    // +Y: top-middle (ceiling).
    else if (face.y == 1.0) {
        p.x = 1.0 / 3.0 + p.x / 3.0;
        p.y = p.y / 2.0;
    }
    // -Y: bottom-middle (floor).
    else if (face.y == -1.0) {
        p.x = 1.0 / 3.0 + p.x / 3.0;
        p.y = 0.5 + p.y / 2.0;
    }
    // +Z: top-right.
    else if (face.z == 1.0) {
        p.x = 2.0 / 3.0 + p.x / 3.0;
        p.y = p.y / 2.0;
    }
    // -Z: bottom-right.
    else if (face.z == -1.0) {
        p.x = 2.0 / 3.0 + p.x / 3.0;
        p.y = 0.5 + p.y / 2.0;
    }

    return texture(cubemap, p).rgb;
}


void vertex() {
    // Centre the projection grid horizontally.
    vec3 delta = vec3(
        room_width * 0.5,
        0.0,
        room_length * 0.5
    );

    // Move the vertical projection grid.
    delta.y = floor_offset;

    obj_vertex = VERTEX - delta;
    obj_cam = inverse(MODELVIEW_MATRIX)[3].xyz - delta;
}


void fragment() {
    vec3 cm_face = vec3(0.0, 0.0, 1.0);
    vec2 cm_uv = UV;

    // Vertical room size.
    float depth = room_depth * 2.0;

    // Ray from camera to current fragment.
    vec3 cam2pix = obj_vertex - obj_cam;


    // --------------------------------------------------
    // Floor / ceiling intersection
    // --------------------------------------------------

    float is_floor = step(cam2pix.y, 0.0);

    float ceil_y = ceil(
        obj_vertex.y / depth - is_floor
    ) * depth;

    float ceil_t = safe_div(
        ceil_y - obj_cam.y,
        cam2pix.y
    );


    // --------------------------------------------------
    // North / south wall intersection (Z axis)
    // --------------------------------------------------

    float is_north = step(cam2pix.z, 0.0);

    float wall_f_z = ceil(
        obj_vertex.z / room_length - is_north
    ) * room_length;

    float wall_f_t = safe_div(
        wall_f_z - obj_cam.z,
        cam2pix.z
    );


    // --------------------------------------------------
    // East / west wall intersection (X axis)
    // --------------------------------------------------

    float is_east = step(cam2pix.x, 0.0);

    float wall_e_x = ceil(
        obj_vertex.x / room_width - is_east
    ) * room_width;

    float wall_e_t = safe_div(
        wall_e_x - obj_cam.x,
        cam2pix.x
    );


    // --------------------------------------------------
    // Select the closest room surface
    // --------------------------------------------------

    vec2 tex_coord;

    float min_t = min(
        min(ceil_t, wall_e_t),
        wall_f_t
    );


    if (wall_e_t == min_t) {
        // East / west wall.
        tex_coord = obj_cam.zy + wall_e_t * cam2pix.zy;

        cm_face = vec3(
            (is_east == 0.0) ? 1.0 : -1.0,
            0.0,
            0.0
        );
    }
    else if (wall_f_t == min_t) {
        // North / south wall.
        tex_coord = obj_cam.xy + wall_f_t * cam2pix.xy;

        cm_face = vec3(
            0.0,
            0.0,
            (is_north == 0.0) ? -1.0 : 1.0
        );
    }
    else {
        // Floor / ceiling.
        tex_coord = obj_cam.xz + ceil_t * cam2pix.xz;

        cm_face = vec3(
            0.0,
            (is_floor == 0.0) ? 1.0 : -1.0,
            0.0
        );
    }


    // Normalize each axis by the room extent it spans, so the
    // full face is sampled for any room size. Projection
    // coordinates run from -extent to 0 on each axis.
    vec2 extent;

    if (wall_e_t == min_t) {
        extent = vec2(room_length, room_depth * 2.0);
    }
    else if (wall_f_t == min_t) {
        extent = vec2(room_width, room_depth * 2.0);
    }
    else {
        extent = vec2(room_width, room_length);
    }

    // Convert projection coordinates to face UVs.
    cm_uv = tex_coord / extent + 1.0;

    // Flip U on the faces that would otherwise appear
    // mirrored when viewed from inside the room (-X and -Z).
    if (cm_face.x == -1.0 || cm_face.z == -1.0) {
        cm_uv.x = 1.0 - cm_uv.x;
    }

    cm_uv = clamp(cm_uv, vec2(0.0), vec2(1.0));


    // --------------------------------------------------
    // Material outputs
    // --------------------------------------------------

    ALBEDO = sample_cubemap(
        cubemap_albedo,
        cm_uv,
        cm_face
    );

    NORMAL_MAP = sample_cubemap(
        cubemap_normalmap,
        cm_uv,
        cm_face
    );

    EMISSION = sample_cubemap(
        cubemap_emission,
        cm_uv,
        cm_face
    ) * emission_strength;
}
