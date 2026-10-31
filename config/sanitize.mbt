///|
/// Reject CSS whose braces do not balance, so a directive cannot close the
/// rule it is placed in.
pub fn sanitize_css(css : String) -> String {
  let mut opened = 0
  let mut closed = 0
  for c in css {
    if opened < closed {
      return "{ /* ERROR: Unbalanced CSS */ }"
    }
    if c == '{' {
      opened += 1
    } else if c == '}' {
      closed += 1
    }
  }
  if opened != closed {
    "{ /* ERROR: Unbalanced CSS */ }"
  } else {
    css
  }
}

///|
fn is_unsafe_key(key : String) -> Bool {
  key.has_prefix("__") || key.contains("proto") || key.contains("constr")
}

///|
/// The characters allowed in a theme variable.
const PLAIN_THEME_VALUE = re"^[0-9 \"#%(),.;A-Za-z]+$"

///|
/// Whether `value` consists only of characters allowed in a theme variable:
/// `[\d "#%(),.;A-Za-z]+`.
fn is_plain_theme_value(value : String) -> Bool {
  value =~ PLAIN_THEME_VALUE
}

///|
/// A `nodeColors` value: a hex color, an `rgb()` or `hsl()` call, or a
/// lowercase keyword.
const NODE_COLOR = re"^(#[0-9a-f]{3,8}|(rgb|hsl)\([0-9 %,\t\n.]+\)|[a-z]+)$"

///|
/// Whether `value` is acceptable for the dictionary option `key`
/// (`nodeColors`, `filenameIcons`, `extensionIcons`), or `None` when `key`
/// is not such an option.
fn dictionary_value_ok(key : String, value : String) -> Bool? {
  let word = (c : Char) => {
    c is ('0'..<='9' | 'A'..<='Z' | 'a'..<='z' | '_' | '-')
  }
  match key {
    "nodeColors" => Some(value.to_lower() =~ NODE_COLOR)
    "filenameIcons" | "extensionIcons" => {
      let parts = value.split(":").collect()
      Some(
        parts.length() is (1 | 2) &&
        parts.all(part => part.length() > 0 && part.all(word)),
      )
    }
    _ => None
  }
}

///|
/// Strip everything from a directive (`%%{init: ...}%%` or frontmatter
/// `config`) that is not a known configuration key or looks unsafe.
pub fn sanitize_directive(directive : Json) -> Json {
  match directive {
    Array(items) => Json::array(items.map(sanitize_directive))
    Object(fields) => {
      let clean : Map[String, Json] = Map([])
      for key, value in fields {
        if is_unsafe_key(key) || !config_keys.contains(key) || value is Null {
          continue
        }
        clean[key] = match value {
          Object(entries) if dictionary_value_ok(key, "") is Some(_) => {
            let kept : Map[String, Json] = Map([])
            for name, entry in entries {
              if !is_unsafe_key(name) &&
                entry is String(text) &&
                dictionary_value_ok(key, text) is Some(true) {
                kept[name] = entry
              }
            }
            Json::object(kept)
          }
          Object(_) | Array(_) => sanitize_directive(value)
          String(text) if ["themeCSS", "fontFamily", "altFontFamily"].any(css_key => {
              key.contains(css_key)
            }) => Json::string(sanitize_css(text))
          _ => value
        }
      }
      if clean.get("themeVariables") is Some(Object(variables)) {
        let checked : Map[String, Json] = Map([])
        for name, value in variables {
          checked[name] = match value {
            String(text) if !is_plain_theme_value(text) => Json::string("")
            _ => value
          }
        }
        clean["themeVariables"] = Json::object(checked)
      }
      Json::object(clean)
    }
    other => other
  }
}

///|
/// Remove keys a diagram may never change — `secure` itself and the keys it
/// lists — along with dunder keys and strings that could carry markup.
fn sanitize(options : Json, secure : Array[String]) -> Json {
  guard options is Object(fields) else { return options }
  let clean : Map[String, Json] = Map([])
  for key, value in fields {
    if key == "secure" || secure.contains(key) || key.has_prefix("__") {
      continue
    }
    match value {
      String(text) if text.contains("<") ||
        text.contains(">") ||
        text.contains("url(data:") => continue
      Object(_) | Array(_) => clean[key] = sanitize(value, secure)
      _ => clean[key] = value
    }
  }
  Json::object(clean)
}
