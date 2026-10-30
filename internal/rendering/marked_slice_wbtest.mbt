///|
test "JavaScript slice preserves surrogate code units" {
  let text = "a😀b"
  let high = js_slice(text, 1, 2)
  let low = js_slice(text, 2, 3)
  assert_eq(high.length(), 1)
  assert_eq(low.length(), 1)
  assert_eq(high[0], text[1])
  assert_eq(low[0], text[2])
  assert_eq(js_slice(text, -3, -1), "😀")
  assert_eq(js_slice(text, -99, 99), text)
  assert_eq(js_slice(text, 3, 1), "")
}
