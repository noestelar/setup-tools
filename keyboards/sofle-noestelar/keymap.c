// Noé's Sofle Layout — Mac + Gaming + Coding
// OLED: Rabbit Hole animation (horizontal) on slave, Alia status (vertical) on master
// VIA enabled
#include QMK_KEYBOARD_H
#include "miku_frames.h"

enum custom_keycodes {
    GM_TOGG = SAFE_RANGE,
};

enum sofle_layers {
    _QWERTY,
    _LOWER,
    _RAISE,
    _ADJUST,
    _GAMING,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

[_QWERTY] = LAYOUT(
  KC_GRV,   KC_1,   KC_2,    KC_3,    KC_4,    KC_5,                       KC_6,    KC_7,    KC_8,    KC_9,    KC_0,  KC_DEL,
  KC_ESC,   KC_Q,   KC_W,    KC_E,    KC_R,    KC_T,                       KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,  KC_BSPC,
  KC_TAB,   KC_A,   KC_S,    KC_D,    KC_F,    KC_G,                       KC_H,    KC_J,    KC_K,    KC_L,  KC_SCLN, KC_QUOT,
  KC_LSFT,  KC_Z,   KC_X,    KC_C,    KC_V,    KC_B,  KC_MUTE,   KC_MPLY,  KC_N,    KC_M,  KC_COMM, KC_DOT,  KC_SLSH, KC_RSFT,
              CTL_T(KC_ESC), KC_LALT, KC_LGUI, TL_LOWR, KC_BSPC,    RSFT_T(KC_SPC), TL_UPPR, KC_LALT, KC_ENT, KC_DEL
),

[_LOWER] = LAYOUT(
  KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,                      KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12,
  KC_GRV,  KC_1,    KC_2,    KC_3,    KC_4,    KC_5,                       KC_6,    KC_7,    KC_8,    KC_9,    KC_0,    _______,
  _______, KC_EXLM, KC_AT,   KC_HASH, KC_DLR,  KC_PERC,                    KC_CIRC, KC_AMPR, KC_ASTR, KC_LPRN, KC_RPRN, KC_PIPE,
  _______, KC_EQL,  KC_MINS, KC_PLUS, KC_LCBR, KC_RCBR, GM_TOGG,  _______, KC_LBRC, KC_RBRC, KC_SCLN, KC_COLN, KC_BSLS, _______,
                    _______, _______, _______, _______, _______,    _______, _______, _______, _______, _______
),

[_RAISE] = LAYOUT(
  _______, _______, _______, _______, _______, _______,                      _______, _______, _______, _______, _______, _______,
  _______, KC_INS,  KC_PSCR, KC_APP,  XXXXXXX, XXXXXXX,                     KC_PGUP, KC_HOME, KC_UP,   KC_END,  XXXXXXX, KC_BSPC,
  _______, KC_LALT, KC_LCTL, KC_LSFT, KC_LGUI, KC_CAPS,                     KC_PGDN, KC_LEFT, KC_DOWN, KC_RGHT, KC_DEL,  _______,
  _______, C(KC_Z), C(KC_X), C(KC_C), C(KC_V), XXXXXXX, _______,  _______, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, _______,
                    _______, _______, _______, _______, _______,    _______, _______, _______, _______, _______
),

[_ADJUST] = LAYOUT(
  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                     XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
  QK_BOOT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                     XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
  XXXXXXX, XXXXXXX, CG_TOGG, XXXXXXX, XXXXXXX, GM_TOGG,                  XXXXXXX, KC_VOLD, KC_MUTE, KC_VOLU, XXXXXXX, XXXXXXX,
  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, KC_MPRV, KC_MPLY, KC_MNXT, XXXXXXX, XXXXXXX,
                     _______, _______, _______, _______, _______,    _______, _______, _______, _______, _______
),

// Gaming: Ctrl on thumb (pure, no mod-tap), no accidental layers
// Exit: LOWER+RAISE+G (3rd left thumb falls through to LOWER)
[_GAMING] = LAYOUT(
  KC_ESC,   KC_1,   KC_2,    KC_3,    KC_4,    KC_5,                       _______, _______, _______, _______, _______, _______,
  KC_TAB,   KC_Q,   KC_W,    KC_E,    KC_R,    KC_T,                       _______, _______, _______, _______, _______, _______,
  KC_GRV,   KC_A,   KC_S,    KC_D,    KC_F,    KC_G,                       _______, _______, _______, _______, _______, _______,
  KC_LSFT,  KC_Z,   KC_X,    KC_C,    KC_V,    KC_B,  _______,   _______, _______, _______, _______, _______, _______, _______,
              KC_LCTL, KC_LALT, _______, KC_SPC, KC_SPC,    _______, _______, _______, _______, _______
)
};

// ============================================================
// Custom keycodes
// ============================================================
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case GM_TOGG:
            if (record->event.pressed) {
                if (IS_LAYER_ON(_GAMING)) {
                    layer_off(_GAMING);
                } else {
                    layer_on(_GAMING);
                }
            }
            return false;
    }
    return true;
}

// ============================================================
// OLED
// ============================================================
#ifdef OLED_ENABLE

oled_rotation_t oled_init_user(oled_rotation_t rotation) {
    if (is_keyboard_master()) {
        return OLED_ROTATION_270;  // Master: vertical status
    }
    return OLED_ROTATION_0;  // Slave: horizontal Rabbit Hole animation
}

// ─── Master OLED: Alia status (vertical 32x128) ───
static void render_status(void) {
    oled_set_cursor(0, 1);
    oled_write_ln_P(PSTR("ALIA"), false);
    oled_write_ln_P(PSTR("-----"), false);

    // Layer
    switch (get_highest_layer(layer_state)) {
        case _QWERTY:  oled_write_ln_P(PSTR("QWRTY"), false); break;
        case _LOWER:   oled_write_ln_P(PSTR("LOWER"), false); break;
        case _RAISE:   oled_write_ln_P(PSTR("RAISE"), false); break;
        case _ADJUST:  oled_write_ln_P(PSTR("ADJST"), false); break;
        case _GAMING:  oled_write_ln_P(PSTR("GAME!"), false); break;
        default:       oled_write_ln_P(PSTR("?????"), false);
    }

    oled_write_ln_P(PSTR(""), false);

    // Mods
    uint8_t mods = get_mods();
    oled_write_P((mods & MOD_MASK_SHIFT) ? PSTR("S") : PSTR("-"), false);
    oled_write_P((mods & MOD_MASK_CTRL)  ? PSTR("C") : PSTR("-"), false);
    oled_write_P((mods & MOD_MASK_ALT)   ? PSTR("A") : PSTR("-"), false);
    oled_write_P((mods & MOD_MASK_GUI)   ? PSTR("G") : PSTR("-"), false);
    oled_write_P(PSTR("\n"), false);

    oled_write_ln_P(PSTR(""), false);

    // Lock indicators
    led_t led = host_keyboard_led_state();
    oled_write_P(led.caps_lock   ? PSTR("C") : PSTR(" "), false);
    oled_write_P(led.num_lock    ? PSTR("N") : PSTR(" "), false);
    oled_write_P(led.scroll_lock ? PSTR("S") : PSTR(" "), false);
    oled_write_P(PSTR("  \n"), false);
}

// ─── Slave OLED: Rabbit Hole animation (horizontal 128x32) ───
#define MIKU_FRAME_DURATION 100  // ms per frame (~10 FPS)

static uint8_t miku_current_frame = 0;
static uint16_t miku_timer = 0;

static void render_miku(void) {
    if (timer_elapsed(miku_timer) > MIKU_FRAME_DURATION) {
        miku_timer = timer_read();
        miku_current_frame = (miku_current_frame + 1) % MIKU_FRAME_COUNT;
    }
    oled_write_raw_P(miku_frames[miku_current_frame], MIKU_FRAME_SIZE);
}

// ─── OLED Task ───
bool oled_task_user(void) {
    if (is_keyboard_master()) {
        render_status();
    } else {
        render_miku();
    }
    return false;
}

#endif  // OLED_ENABLE

// Encoder
#ifdef ENCODER_ENABLE
bool encoder_update_user(uint8_t index, bool clockwise) {
    if (index == 0) {
        if (get_highest_layer(layer_state) == _LOWER) {
            tap_code16(clockwise ? C(KC_Y) : C(KC_Z));
        } else {
            tap_code(clockwise ? KC_VOLU : KC_VOLD);
        }
    } else if (index == 1) {
        if (get_highest_layer(layer_state) == _RAISE) {
            tap_code(clockwise ? KC_RIGHT : KC_LEFT);
        } else {
            tap_code(clockwise ? KC_PGDN : KC_PGUP);
        }
    }
    return false;
}
#endif
