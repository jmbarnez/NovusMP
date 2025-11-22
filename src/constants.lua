local Constants = {}

Constants.BACKGROUND = {
    STAR_SIZE = 16,
    STAR_SPRITE_BATCH_SIZE = 3000,
    STAR_COUNT = 200,
    CLEAR_COLOR = {0.005, 0.005, 0.015, 1},

    STAR_COLORS = {
        {0.6, 0.7, 1.0},
        {0.75, 0.85, 1.0},
        {0.95, 0.95, 1.0},
        {1.0, 1.0, 0.95},
        {1.0, 0.95, 0.8},
        {1.0, 0.85, 0.6},
        {1.0, 0.7, 0.5}
    },

    STAR_COLOR_WEIGHTS = {0.03, 0.08, 0.12, 0.15, 0.20, 0.22, 0.20},

    LAYER_THRESHOLDS = {
        NEAR = 0.2,
        MID = 0.6
    },

    LAYER_PARAMS = {
        [3] = {
            SIZE_MIN = 0.06,
            SIZE_FACTOR = 0.18,
            SPEED_MIN = 0.006,
            SPEED_FACTOR = 0.010,
            ALPHA_MIN = 0.5,
            ALPHA_FACTOR = 0.5
        },
        [2] = {
            SIZE_MIN = 0.03,
            SIZE_FACTOR = 0.14,
            SPEED_MIN = 0.003,
            SPEED_FACTOR = 0.007,
            ALPHA_MIN = 0.3,
            ALPHA_FACTOR = 0.5
        },
        [1] = {
            SIZE_MIN = 0.015,
            SIZE_FACTOR = 0.10,
            SPEED_MIN = 0.001,
            SPEED_FACTOR = 0.005,
            ALPHA_MIN = 0.15,
            ALPHA_FACTOR = 0.4
        }
    },

    MIN_STAR_SIZE = 0.12,

    TWINKLE_SPEED_BASE = 0.5,
    TWINKLE_SPEED_RANGE = 1.5,
    TWINKLE_AMP_BASE = 0.3,
    TWINKLE_AMP_RANGE = 0.4,

    NEBULA = {
        NOISE_SCALE_BASE = 3.0,
        NOISE_SCALE_RANGE = 2.0,
        FLOW_SPEED_BASE = 0.00001,
        FLOW_SPEED_RANGE = 0.00002,
        ALPHA_SCALE_BASE = 0.18,
        ALPHA_SCALE_RANGE = 0.25,
        INTENSITY_BASE = 0.4,
        INTENSITY_RANGE = 0.35,
        HUE_SHIFT_RANGE = 0.25
    }
}

return Constants
