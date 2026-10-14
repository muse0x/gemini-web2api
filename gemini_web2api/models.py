"""Model definitions and mapping from Gemini frontend JS source."""

# MODE_CATEGORY values from Gemini Web; ULTRA is inferred from the current frontend.
#   1=FAST, 2=THINKING, 3=PRO, 4=AUTO, 5=FAST_DYNAMIC_THINKING, 6=FLASH_LITE, 7=ULTRA

MODELS = {
    "gemini-4-argon": {
        "mode": 7, "think": 4,
        "desc": "Gemini 4 Argon (requires a supported Google AI plan)",
    },
    "gemini-3.8-flash": {
        "mode": 1, "think": 4,
        "desc": "Latest Gemini Flash model",
    },
    "gemini-3.6-flash": {
        "mode": 1, "think": 4,
        "desc": "Previous-generation Gemini Flash model",
    },
    "gemini-3.5-flash-lite": {
        "mode": 6, "think": 4,
        "desc": "Fast, cost-efficient Gemini Flash-Lite model",
    },
    "gemini-3.1-pro-preview": {
        "mode": 3, "think": 4,
        "desc": "Gemini 3.1 Pro preview (requires account cookie)",
    },
    "gemini-auto": {
        "mode": 4, "think": 4,
        "desc": "Auto model selection",
    },
}

LEGACY_MODEL_ALIASES = {
    "gemini-3.7-flash": ("gemini-3.8-flash", None),
    "gemini-3.5-flash": ("gemini-3.6-flash", None),
    "gemini-3.5-flash-thinking": ("gemini-3.8-flash", 0),
    "gemini-3.5-flash-thinking-lite": ("gemini-3.8-flash", 0),
    "gemini-3.1-pro": ("gemini-3.1-pro-preview", None),
    "gemini-3.1-pro-enhanced": ("gemini-3.1-pro-preview", None),
    "gemini-flash-lite": ("gemini-3.5-flash-lite", None),
}


def resolve_model(model_name: str, default: str = "gemini-3.8-flash"):
    """Resolve model name to (name, mode_id, think_mode, error, extra_fields).

    Unknown model names fall back to default rather than erroring,
    since upstream clients may request arbitrary model identifiers.
    """
    think_override = None
    if "@think=" in model_name:
        model_name, think_str = model_name.rsplit("@think=", 1)
        try:
            think_override = int(think_str)
        except ValueError:
            return None, None, None, f"Invalid think level: {think_str}", None
    alias = LEGACY_MODEL_ALIASES.get(model_name)
    if alias:
        model_name, alias_think = alias
        if think_override is None:
            think_override = alias_think
    cfg = MODELS.get(model_name)
    if not cfg:
        from .gemini import log
        log(f"Unknown model '{model_name}', falling back to '{default}'")
        model_name = default
        cfg = MODELS[default]
    mode_id = cfg["mode"]
    think_mode = think_override if think_override is not None else cfg["think"]
    extra = cfg.get("extra")
    return model_name, mode_id, think_mode, None, extra
