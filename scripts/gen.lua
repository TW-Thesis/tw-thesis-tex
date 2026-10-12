#!/usr/bin/env texlua
-- config.yml + schools/<school>.yml + schools/default.yml -> .tw-thesis-config.tex
--
-- LaTeX cannot read YAML, so this does what lib/config.typ does in the Typst
-- template: merge the three layers (default <- school <- config.yml), reject
-- unknown keys, fill the {placeholders}, turn units into TeX lengths, and write
-- the result as `\twcfg{key}{value}` definitions that tw-thesis.cls reads back
-- with `\twget{key}`. It also prepares the bibliography: BibTeX, CSL JSON and
-- CSL YAML pass through to citeproc-lua, Hayagriva YAML becomes CSL JSON.
--
-- It runs on texlua, which every TeX distribution ships, so nothing but TeX
-- (and the lua-tinyyaml package that citation-style-language needs anyway) has
-- to be installed:
--
--     texlua scripts/gen.lua [config.yml] [-o .tw-thesis-config.tex]

if kpse and kpse.set_program_name then kpse.set_program_name("texlua") end
local tinyyaml = require("tinyyaml")
local lfs = require("lfs")

local gen = {}

-- --------------------------------------------------------------------------
-- small helpers
-- --------------------------------------------------------------------------

-- YAML `~` (and `null`) read as this, so a key can be present and empty
local NULL = setmetatable({}, { __tostring = function() return "null" end })
gen.NULL = NULL

local function fail(message) error({ config_error = message }, 0) end

local function is_null(v) return v == nil or v == NULL end
local function is_table(v) return type(v) == "table" and v ~= NULL end
local function is_list(v) return is_table(v) and v[1] ~= nil end
local function is_dict(v) return is_table(v) and v[1] == nil and next(v) ~= nil end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local function contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

local function set(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

local function split(s, sep)
  local out, from = {}, 1
  while true do
    local a, b = s:find(sep, from, true)
    if not a then out[#out + 1] = s:sub(from); return out end
    out[#out + 1] = s:sub(from, a - 1)
    from = b + 1
  end
end

local function split_words(s)
  local out = {}
  for w in s:gmatch("%S+") do out[#out + 1] = w end
  return out
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function rstrip(s) return (s:gsub("%s+$", "")) end

local function replace_plain(s, old, new)
  local out, from = {}, 1
  while true do
    local a, b = s:find(old, from, true)
    if not a then out[#out + 1] = s:sub(from); break end
    out[#out + 1] = s:sub(from, a - 1)
    out[#out + 1] = new
    from = b + 1
  end
  return table.concat(out)
end

local function ends_with(s, suffix) return suffix == "" or s:sub(-#suffix) == suffix end

local function copy(v)
  if not is_table(v) then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local s = f:read("a")
  f:close()
  return s
end

local function write_file(path, text)
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

-- keep the old file (and its mtime) when nothing changed, so builds stay quiet
local function write_if_changed(path, text)
  if read_file(path) == text then return end
  write_file(path, text)
end

local function mkdir_p(path)
  local built = path:sub(1, 1) == "/" and "/" or ""
  for part in path:gmatch("[^/]+") do
    built = built .. part
    if not lfs.attributes(built) then lfs.mkdir(built) end
    built = built .. "/"
  end
end

local function is_file(path)
  local a = lfs.attributes(path)
  return a ~= nil and a.mode == "file"
end

local function normalize_path(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." and #parts > 0 and parts[#parts] ~= ".." then parts[#parts] = nil
    elseif part ~= "." then parts[#parts + 1] = part end
  end
  return (path:sub(1, 1) == "/" and "/" or "") .. table.concat(parts, "/")
end

local function absolute(path)
  if path:sub(1, 1) ~= "/" then path = lfs.currentdir() .. "/" .. path end
  return normalize_path(path)
end

local function dirname(path) return path:match("^(.*)/[^/]*$") or "." end
local function basename(path) return path:match("([^/]*)$") end
local function stem(path) return (basename(path):gsub("%.[^.]*$", "")) end

-- --------------------------------------------------------------------------
-- YAML and JSON
-- --------------------------------------------------------------------------

-- tinyyaml reads `~` as the string "~" and a date as an object; make both plain
local function normalize(v)
  if v == "~" or v == "null" then return NULL end
  if type(v) == "number" then
    if math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 2 ^ 53 then
      return math.tointeger(v)
    end
    return v
  end
  if type(v) ~= "table" then return v end
  local mt = getmetatable(v)
  if mt and mt.__tostring then
    local text = tostring(v)
    if text == "yaml.null" then return NULL end
    return text   -- a timestamp
  end
  local out = {}
  for k, x in pairs(v) do out[k] = normalize(x) end
  return out
end

local function parse_yaml(text, where)
  local ok, result = pcall(tinyyaml.parse, text)
  if not ok then fail(where .. ": invalid YAML (" .. tostring(result) .. ")") end
  if result == nil then return {} end
  return normalize(result)
end

local function read_yaml(path)
  local text, err = read_file(path)
  if not text then fail("cannot read " .. path .. " (" .. tostring(err) .. ")") end
  return parse_yaml(text, path)
end

-- top-level keys in the order the file lists them (tinyyaml loses the order)
local function top_level_keys(text)
  local keys, seen = {}, {}
  for line in text:gmatch("[^\r\n]+") do
    local key = line:match("^([^%s#%-][^:]*):%s*") or line:match('^"([^"]+)":') or line:match("^'([^']+)':")
    if key then
      key = trim(key):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
      if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
  end
  return keys
end

local function json_string(s)
  s = s:gsub('[%c"\\]', function(c)
    local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }
    return named[c] or string.format("\\u%04x", c:byte())
  end)
  return '"' .. s .. '"'
end

-- like Python's json.dumps(indent=2, sort_keys=True, ensure_ascii=False)
local function json_encode(v, indent)
  indent = indent or ""
  if v == NULL or v == nil then return "null" end
  local t = type(v)
  if t == "string" then return json_string(v) end
  if t == "number" then return tostring(v) end
  if t == "boolean" then return tostring(v) end
  local inner = indent .. "  "
  if next(v) == nil then return "[]" end
  local parts = {}
  if v[1] ~= nil then
    for _, x in ipairs(v) do parts[#parts + 1] = inner .. json_encode(x, inner) end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
  end
  for _, k in ipairs(sorted_keys(v)) do
    parts[#parts + 1] = inner .. json_string(tostring(k)) .. ": " .. json_encode(v[k], inner)
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- a small JSON reader: enough to find the ids in a CSL JSON file
local function json_decode(text, where)
  local pos = 1
  local function err(msg) fail(where .. ": invalid JSON (" .. msg .. " at " .. pos .. ")") end
  local function skip() pos = text:find("%S", pos) or #text + 1 end
  local value
  local function str()
    local out = {}
    pos = pos + 1
    while true do
      local c = text:sub(pos, pos)
      if c == "" then err("unterminated string") end
      if c == '"' then pos = pos + 1; return table.concat(out) end
      if c == "\\" then
        local n = text:sub(pos + 1, pos + 1)
        local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
        if n == "u" then
          local hex = text:sub(pos + 2, pos + 5)
          if not hex:match("^%x%x%x%x$") then err("bad escape") end
          local cp = tonumber(hex, 16)
          if cp >= 0xD800 and cp < 0xDC00 and text:sub(pos + 6, pos + 7) == "\\u" then
            local low = tonumber(text:sub(pos + 8, pos + 11), 16)
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
            pos = pos + 6
          end
          out[#out + 1] = utf8.char(cp)
          pos = pos + 6
        else
          if not map[n] then err("bad escape") end
          out[#out + 1] = map[n]
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
  end
  function value()
    skip()
    local c = text:sub(pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
      while true do
        skip()
        if text:sub(pos, pos) ~= '"' then err("expected a key") end
        local k = str(); skip()
        if text:sub(pos, pos) ~= ":" then err("expected ':'") end
        pos = pos + 1
        obj[k] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "}" then return obj end
        if d ~= "," then err("expected ',' or '}'") end
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "]" then return arr end
        if d ~= "," then err("expected ',' or ']'") end
      end
    elseif c == '"' then return str()
    elseif text:find("^true", pos) then pos = pos + 4; return true
    elseif text:find("^false", pos) then pos = pos + 5; return false
    elseif text:find("^null", pos) then pos = pos + 4; return NULL
    else
      local num = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
      if not num or num == "" then err("unexpected character") end
      pos = pos + #num
      return tonumber(num)
    end
  end
  local result = value()
  skip()
  if pos <= #text then err("trailing text") end
  return result
end

-- --------------------------------------------------------------------------
-- bibliography: Hayagriva -> CSL JSON
-- --------------------------------------------------------------------------

local function csl_item(item) return is_dict(item) and item.id ~= nil and item.type ~= nil end

local function all_csl_items(list)
  if not is_list(list) then return false end
  for _, item in ipairs(list) do if not csl_item(item) then return false end end
  return true
end

-- tell Hayagriva (key -> entry mapping) from CSL YAML (item sequence)
local function classify_yaml(data, name)
  if is_list(data) then
    if all_csl_items(data) then return "csl" end
    fail(name .. ": a top-level list must hold CSL items with `id` and `type`")
  end
  if is_dict(data) then
    if is_list(data.references) then
      if all_csl_items(data.references) then return "csl" end
      fail(name .. ": `references` must hold CSL items with `id` and `type`")
    end
    local all_tables = true
    for _, v in pairs(data) do if not is_dict(v) then all_tables = false end end
    if all_tables then return "hayagriva" end
    if csl_item(data) then
      fail(name .. ": a single CSL item must be wrapped in a list or `references:`")
    end
  end
  fail(name .. ": neither Hayagriva (mapping of key -> entry) nor CSL YAML (list or `references:` of items)")
end

local HAYAGRIVA_FIELDS = set {
  "type", "title", "author", "date", "parent", "abstract", "genre", "editor",
  "affiliated", "call-number", "publisher", "location", "organization",
  "issue", "volume", "volume-total", "chapter", "edition", "page-range",
  "page-total", "time-range", "runtime", "url", "serial-number", "language",
  "archive", "archive-location", "note",
}

-- entry type -> type of its parent when the parent omits `type`
local DEFAULT_PARENT = {
  article = "periodical", chapter = "book", entry = "reference", anthos = "anthology",
  web = "web", scene = "video", artwork = "exhibition", legislation = "anthology",
  post = "post", video = "video", audio = "audio",
}

local HAYAGRIVA_TYPES = set {
  "article", "chapter", "entry", "anthos", "report", "thesis", "web", "scene",
  "artwork", "patent", "case", "newspaper", "legislation", "manuscript",
  "original", "post", "misc", "performance", "periodical", "proceedings",
  "book", "blog", "reference", "conference", "anthology", "repository",
  "thread", "video", "audio", "exhibition",
}

-- entry type -> CSL type (articles are refined by their parent below)
local CSL_TYPES = {
  article = "article", chapter = "chapter", entry = "entry", anthos = "chapter",
  report = "report", thesis = "thesis", web = "webpage", scene = "motion_picture",
  artwork = "graphic", patent = "patent", case = "legal_case",
  newspaper = "article-newspaper", legislation = "legislation",
  manuscript = "manuscript", original = "document", post = "post",
  misc = "document", performance = "performance", periodical = "periodical",
  proceedings = "book", book = "book", blog = "webpage", reference = "book",
  conference = "event", anthology = "collection", repository = "software",
  thread = "post", video = "motion_picture", audio = "song", exhibition = "event",
}

local ARTICLE_BY_PARENT = {
  periodical = "article-journal", newspaper = "article-newspaper",
  proceedings = "paper-conference", blog = "post-weblog", report = "report",
  thesis = "thesis", manuscript = "manuscript",
}

local EVENT_TYPES = set { "conference", "exhibition", "performance" }

-- affiliated role (lowercase, without `-`/`_`) -> CSL name variable
local ROLE_VARIABLES = {
  translator = "translator", afterword = "contributor", foreword = "contributor",
  introduction = "contributor", annotator = "contributor", commentator = "contributor",
  holder = "contributor", compiler = "compiler", founder = "series-creator",
  collaborator = "contributor", organizer = "organizer", castmember = "performer",
  composer = "composer", producer = "producer", executiveproducer = "executive-producer",
  writer = "script-writer", cinematography = "contributor", director = "director",
  illustrator = "illustrator", narrator = "narrator",
}

local SERIAL_VARIABLES = {
  doi = "DOI", isbn = "ISBN", issn = "ISSN", pmid = "PMID", pmcid = "PMCID", serial = "number",
}

-- fields that map one-to-one onto a CSL variable
local SIMPLE_FIELDS = {
  abstract = "abstract", genre = "genre", ["call-number"] = "call-number",
  issue = "issue", volume = "volume", ["volume-total"] = "number-of-volumes",
  chapter = "chapter-number", edition = "edition", ["page-range"] = "page",
  ["page-total"] = "number-of-pages", ["time-range"] = "section", runtime = "dimensions",
  language = "language", archive = "archive", ["archive-location"] = "archive_location",
  note = "note",
}

-- the title of a parent lands in the first free one of these
local CONTAINER_TITLES = { "container-title", "collection-title", "event-title" }

local function text_of(v) return trim(tostring(v)) end

-- a formattable string is plain text or `{value, short, verbatim}`
local function formattable(value, where)
  if is_dict(value) then
    if value.value == nil then fail(where .. ": a formattable string needs `value`") end
    return text_of(value.value), (value.short ~= nil and text_of(value.short) or nil)
  end
  return text_of(value), nil
end

local function first_char_is_lower(word)
  local first = word:match(utf8.charpattern)
  return first ~= nil and first:match("^%l$") ~= nil
end

-- `Family, Given`, `prefix Family, Suffix, Given` or the mapping form
local function person_name(person, where)
  if is_dict(person) then
    if person.name == nil then fail(where .. ": a person mapping needs `name`") end
    if person.alias ~= nil then return { literal = text_of(person.alias) } end  -- CSL has no alias
    local out = { family = text_of(person.name) }
    if person["given-name"] ~= nil then out.given = text_of(person["given-name"]) end
    if person.prefix ~= nil then out["non-dropping-particle"] = text_of(person.prefix) end
    if person.suffix ~= nil then out.suffix = text_of(person.suffix) end
    return out
  end
  local parts = {}
  for _, p in ipairs(split(text_of(person), ",")) do parts[#parts + 1] = trim(p) end
  if #parts == 1 then return { literal = parts[1] } end
  if #parts > 3 then fail(where .. ": `" .. tostring(person) .. "` has too many commas for a name") end
  local words = split_words(parts[1])
  local lead = 0
  while lead < #words - 1 and first_char_is_lower(words[lead + 1]) do lead = lead + 1 end
  local out = { family = table.concat(words, " ", lead + 1), given = parts[#parts] }
  if lead > 0 then out["non-dropping-particle"] = table.concat(words, " ", 1, lead) end
  if #parts == 3 then out.suffix = parts[2] end
  return out
end

local function person_names(value, where)
  local items = is_list(value) and value or { value }
  local out = {}
  for _, p in ipairs(items) do out[#out + 1] = person_name(p, where) end
  return out
end

local function csl_date(value, where)
  local parts
  if type(value) == "number" then
    parts = { value }
  else
    local s = text_of(value)
    local y, m, d = s:match("^(%-?%d%d%d%d)%-(%d%d)%-(%d%d)T")   -- a YAML timestamp
    if y then
      parts = { tonumber(y), tonumber(m), tonumber(d) }
    else
      y, m, d = s:match("^(%-?%d%d%d%d)%-?(%d?%d?)%-?(%d?%d?)$")
      if not y or (m ~= "" and #m ~= 2) or (d ~= "" and #d ~= 2) or (m == "" and d ~= "")
          or (s:find("%-", 2) and not s:match("^%-?%d%d%d%d%-%d%d") ) then
        fail(where .. ": `" .. s .. "` is not an ISO date (YYYY, YYYY-MM or YYYY-MM-DD)")
      end
      parts = { tonumber(y) }
      if m ~= "" then parts[2] = tonumber(m) end
      if d ~= "" then parts[3] = tonumber(d) end
    end
  end
  return { ["date-parts"] = { parts } }
end

local function entry_type(entry, parent_of, where)
  local raw = entry.type
  local kind = raw ~= nil and text_of(raw):lower() or (DEFAULT_PARENT[parent_of or ""] or "misc")
  if not HAYAGRIVA_TYPES[kind] then
    fail(where .. ": type `" .. tostring(raw) .. "` is not a Hayagriva entry type")
  end
  return kind
end

local function check_fields(entry, where)
  for _, field in ipairs(sorted_keys(entry)) do
    if not HAYAGRIVA_FIELDS[field] then fail(where .. ": unknown field `" .. field .. "`") end
  end
end

-- flatten the parent tree into { depth, entry, type }, nearest first
local function parents_of(entry, kind, where)
  local out = {}
  local raw = entry.parent
  if raw == nil then return out end
  for _, parent in ipairs(is_list(raw) and raw or { raw }) do
    if not is_dict(parent) then fail(where .. ": `parent` must be an entry or a list of entries") end
    check_fields(parent, where .. ", parent")
    local ptype = entry_type(parent, kind, where .. ", parent")
    out[#out + 1] = { 0, parent, ptype }
    for _, nested in ipairs(parents_of(parent, ptype, where .. ", parent")) do
      out[#out + 1] = { nested[1] + 1, nested[2], nested[3] }
    end
  end
  return out
end

local function append_all(list, extra) for _, x in ipairs(extra) do list[#list + 1] = x end end

-- translate the fields of one entry; parents name their title and authors differently
local function map_fields(entry, kind, where, parent_depth)
  local out = {}
  local is_parent = parent_depth ~= nil
  for _, field in ipairs(sorted_keys(entry)) do
    local value = entry[field]
    local w = where .. ", field `" .. field .. "`"
    if field == "type" or field == "parent" then
      -- handled elsewhere
    elseif field == "title" then
      local text, short = formattable(value, w)
      local var
      if not is_parent then var = "title"
      elseif EVENT_TYPES[kind] then var = "event-title"
      else var = parent_depth == 0 and "container-title" or "collection-title" end
      out[var] = text
      if short and short ~= "" then out[var .. "-short"] = short end
    elseif field == "author" then
      out[is_parent and "container-author" or "author"] = person_names(value, w)
    elseif field == "editor" then
      out.editor = person_names(value, w)
    elseif field == "affiliated" then
      local groups = is_list(value) and value or { value }
      for _, item in ipairs(groups) do
        for _, group in ipairs(is_list(item) and item or { item }) do
          if not is_dict(group) or group.role == nil or group.names == nil then
            fail(w .. ": each item needs `role` and `names`")
          end
          local role = text_of(group.role):lower():gsub("[-_ ]", "")
          if not ROLE_VARIABLES[role] then fail(w .. ": unknown role `" .. tostring(group.role) .. "`") end
          local var = ROLE_VARIABLES[role]
          out[var] = out[var] or {}
          append_all(out[var], person_names(group.names, w))
        end
      end
    elseif field == "date" then
      out.issued = csl_date(value, w)
    elseif field == "publisher" then
      if is_dict(value) and value.name ~= nil then
        out.publisher = (formattable(value.name, w))
        if value.location ~= nil then out["publisher-place"] = (formattable(value.location, w)) end
      else
        out.publisher = (formattable(value, w))
      end
    elseif field == "location" then
      out[EVENT_TYPES[kind] and "event-place" or "publisher-place"] = (formattable(value, w))
    elseif field == "organization" then
      out._organization = (formattable(value, w))
    elseif field == "url" then
      if is_dict(value) then
        out.URL = text_of(value.value)
        if value.date ~= nil then out.accessed = csl_date(value.date, w) end
      else
        out.URL = text_of(value)
      end
    elseif field == "serial-number" then
      if is_dict(value) then
        for _, scheme in ipairs(sorted_keys(value)) do
          local number = value[scheme]
          local lower = tostring(scheme):lower()
          if lower == "arxiv" then
            out.number = text_of(number)
            out._arxiv = text_of(number)
          elseif SERIAL_VARIABLES[lower] then
            -- an explicit `serial` never overwrites the arXiv number
            if not (lower == "serial" and out._arxiv) then out[SERIAL_VARIABLES[lower]] = text_of(number) end
          else
            fail(w .. ": unknown serial number scheme `" .. lower .. "`")
          end
        end
      else
        out.number = text_of(value)
      end
    else
      out[SIMPLE_FIELDS[field]] = (formattable(value, w))
    end
  end
  return out
end

local function csl_type(kind, parent_types)
  if kind == "article" then
    for _, ptype in ipairs(parent_types) do
      if ARTICLE_BY_PARENT[ptype] then return ARTICLE_BY_PARENT[ptype] end
    end
  end
  if kind == "entry" and contains(parent_types, "reference") then return "entry-encyclopedia" end
  return CSL_TYPES[kind]
end

local function convert_entry(key, entry, name)
  local where = name .. ": entry `" .. key .. "`"
  if not is_dict(entry) then fail(where .. ": must be a mapping of fields") end
  check_fields(entry, where)
  local kind = entry_type(entry, nil, where)
  local parents = parents_of(entry, kind, where)
  local ptypes = {}
  for _, p in ipairs(parents) do ptypes[#ptypes + 1] = p[3] end
  local item = { id = key, type = csl_type(kind, ptypes) }
  for k, v in pairs(map_fields(entry, kind, where, nil)) do item[k] = v end
  for _, p in ipairs(parents) do
    local mapped = map_fields(p[2], p[3], where .. ", parent", p[1])
    for _, var in ipairs(sorted_keys(mapped)) do
      local target = var
      if contains(CONTAINER_TITLES, var) and item[var] ~= nil then
        for _, free in ipairs(CONTAINER_TITLES) do
          if item[free] == nil then target = free; break end
        end
      end
      if item[target] == nil then item[target] = mapped[var] end
    end
  end
  -- the closest publisher-ish metadata wins; organizations stand in for it
  local organization = item._organization
  item._organization = nil
  if organization and organization ~= "" then
    if item.publisher == nil then item.publisher = organization end
    if item.publisher ~= organization then item.authority = organization end
  end
  local arxiv = item._arxiv
  item._arxiv = nil
  if arxiv and arxiv ~= "" and item.URL == nil then item.URL = "https://arxiv.org/abs/" .. arxiv end
  return item
end

-- convert a Hayagriva mapping of key -> entry into CSL JSON items, in file order
local function hayagriva_to_csl(data, name, text)
  if classify_yaml(data, name) ~= "hayagriva" then fail(name .. ": not a Hayagriva file") end
  local order, seen = {}, {}
  for _, k in ipairs(text and top_level_keys(text) or {}) do
    if data[k] ~= nil and not seen[k] then seen[k] = true; order[#order + 1] = k end
  end
  for _, k in ipairs(sorted_keys(data)) do
    if not seen[k] then seen[k] = true; order[#order + 1] = k end
  end
  local items = {}
  for _, key in ipairs(order) do items[#items + 1] = convert_entry(tostring(key), data[key], name) end
  return items
end

-- --------------------------------------------------------------------------
-- bibliography resources
-- --------------------------------------------------------------------------

local function csl_ids(items)
  if is_dict(items) then items = items.references or {} end
  local ids = {}
  for _, i in ipairs(items) do
    if is_dict(i) and i.id ~= nil then ids[#ids + 1] = tostring(i.id) end
  end
  return ids
end

local function bib_keys(text)
  local keys = {}
  for kind, key in text:gmatch("@(%w+)%s*[{(]%s*([^,%s{}()]+)%s*,") do
    kind = kind:lower()
    if kind ~= "comment" and kind ~= "string" and kind ~= "preamble" then keys[#keys + 1] = key end
  end
  return keys
end

-- the files `\addbibresource` should load, in the order given: .bib, CSL JSON and
-- CSL YAML pass through, Hayagriva YAML becomes CSL JSON inside `build_dir`
local function prepare_resources(paths, build_dir)
  local out, seen = {}, {}
  for index, path in ipairs(paths) do
    if not is_file(path) then fail("bibliography.path: " .. path .. " not found") end
    local suffix = (path:match("(%.[^./]+)$") or ""):lower()
    local text = read_file(path)
    local kind, ids, result
    if suffix == ".bib" then
      kind, result, ids = "bib", path, bib_keys(text)
    elseif suffix == ".json" then
      kind, result = "json", path
      ids = csl_ids(json_decode(text, path))
    elseif suffix == ".yml" or suffix == ".yaml" then
      local data = parse_yaml(text, path)
      kind = classify_yaml(data, path)
      if kind == "hayagriva" then
        result = string.format("%s/%02d-%s.json", build_dir, index - 1, stem(path))
        local json = json_encode(hayagriva_to_csl(data, path, text)) .. "\n"
        mkdir_p(build_dir)
        write_if_changed(result, json)   -- keep the mtime when unchanged
        ids = {}
        for k in pairs(data) do ids[#ids + 1] = tostring(k) end
      else
        result = path
        ids = csl_ids(data)
      end
    else
      fail("bibliography.path: " .. path .. " must be .bib, a Hayagriva/CSL .yml/.yaml, or CSL .json")
    end
    for _, key in ipairs(ids) do
      if seen[key] and seen[key] ~= path then
        fail("citation key `" .. key .. "` is defined in both " .. seen[key] .. " and " .. path)
      end
      seen[key] = seen[key] or path
    end
    out[#out + 1] = result
  end
  return out
end

-- --------------------------------------------------------------------------
-- configuration
-- --------------------------------------------------------------------------

local SCHOOL_KEYS = { "university", "university-en" }
local THESIS_KEYS = {
  "school", "title", "title-en", "author", "author-en", "id", "advisor",
  "advisor-en", "college", "college-en", "institute", "institute-en",
  "degree", "degree-en", "type", "type-en", "date", "oral-date",
  "keywords", "keywords-en",
}

-- Typst's built-in style names that the CSL repository files (shipped with
-- citation-style-language) spell differently
local CSL_STYLE_IDS = { mla = "modern-language-association", ["chicago-notes"] = "chicago-note-bibliography" }

local ROOT, SCHOOLS, I18N, BUILD_DIR

local function merge(base, over)
  local out = copy(base)
  for k, v in pairs(over) do
    local old = base[k]
    if is_dict(v) and is_dict(old) then out[k] = merge(old, v) else out[k] = copy(v) end
  end
  return out
end

-- every key in `over` must exist in `schema`, recursively
local function check(over, schema, file, extra, prefix)
  prefix = prefix or ""
  for _, k in ipairs(sorted_keys(over)) do
    local v = over[k]
    local name = prefix .. k
    if not (prefix == "" and extra[k]) then
      if schema[k] == nil then fail(file .. ": unknown key `" .. name .. "` (see schools/default.yml)") end
      local s = schema[k]
      if is_dict(s) then
        if not is_dict(v) then fail(file .. ": `" .. name .. "` must be a table of keys") end
        check(v, s, file, {}, name .. ".")
      elseif is_dict(v) then
        fail(file .. ": `" .. name .. "` must be a single value, not a table")
      end
    end
  end
end

-- i18n/en.yml's keys become `xxx-en` beside i18n/zh.yml's `xxx`
local function i18n_strings()
  local zh = read_yaml(I18N .. "/zh.yml").strings
  local en = read_yaml(I18N .. "/en.yml").strings
  for k, v in pairs(en) do zh[k .. "-en"] = v end
  return zh
end

local function load_config(config)
  local base = read_yaml(SCHOOLS .. "/default.yml")
  base.strings = merge(base.strings, i18n_strings())
  local user = read_yaml(config)
  local extra = set(THESIS_KEYS)
  for _, k in ipairs(SCHOOL_KEYS) do extra[k] = true end
  check(user, base, basename(config), extra)
  local cfg = base
  if user.school ~= nil then
    local file = SCHOOLS .. "/" .. tostring(user.school) .. ".yml"
    if not is_file(file) then
      fail(basename(config) .. ": no such school `" .. tostring(user.school) .. "` (no schools/" .. basename(file) .. ")")
    end
    local school = read_yaml(file)
    check(school, base, "schools/" .. basename(file), set(SCHOOL_KEYS))
    for _, k in ipairs(SCHOOL_KEYS) do
      if school[k] == nil then fail("schools/" .. basename(file) .. ": missing required key `" .. k .. "`") end
    end
    cfg = merge(cfg, school)
  end
  cfg = merge(cfg, user)
  for _, k in ipairs(THESIS_KEYS) do
    if k ~= "school" and cfg[k] == nil then
      fail(basename(config) .. ": missing key `" .. k .. "` (see the example config.yml)")
    end
  end
  return cfg
end

-- ---- value helpers ----

local function num(x)
  local n = tonumber(x)
  if n == nil then fail("expected a number, got `" .. tostring(x) .. "`") end
  local s = string.format("%.4f", n)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  return s
end

local function em_to_pt(em, size) return num(tonumber(em) * tonumber(size)) .. "pt" end

local TEX_SPECIALS = {
  ["\\"] = "\\textbackslash{}", ["{"] = "\\{", ["}"] = "\\}", ["#"] = "\\#", ["$"] = "\\$",
  ["%"] = "\\%", ["&"] = "\\&", ["_"] = "\\_", ["^"] = "\\^{}",
}

-- escape plain text for TeX; `~` is a hair gap in a title (`spread`) and a
-- non-breaking space elsewhere, a newline becomes a line break
local function tex(s, spread)
  local out = {}
  for ch in tostring(s):gmatch(utf8.charpattern) do
    if ch == "~" then out[#out + 1] = spread and "\\twspread{}" or "\\nobreakspace{}"
    elseif ch == "\n" then out[#out + 1] = "\\\\ "
    else out[#out + 1] = TEX_SPECIALS[ch] or ch end
  end
  return rstrip(table.concat(out))
end

local function fill(template, vars)
  for _, k in ipairs(sorted_keys(vars)) do
    template = replace_plain(template, "{" .. k .. "}", tostring(vars[k]))
  end
  return template
end

-- escape everything but the {C}/{S}/{B} placeholders
local function tex_keep_macros(s)
  local out, pos = {}, 1
  local function text(piece) out[#out + 1] = tex(piece) .. piece:sub(#rstrip(piece) + 1) end
  while true do
    local a, b = s:find("{[CSB]}", pos)
    if not a then text(s:sub(pos)); break end
    text(s:sub(pos, a - 1))
    out[#out + 1] = s:sub(a, b)
    pos = b + 1
  end
  return table.concat(out)
end

-- "第{C}章" -> 第\twcrC{}章; "C.S.B" is shorthand for "{C}.{S}.{B}"
local function cross_ref_format(template)
  local all = true
  for _, t in ipairs(split(template, ".")) do if t ~= "C" and t ~= "S" and t ~= "B" then all = false end end
  if all then
    local parts = {}
    for _, t in ipairs(split(template, ".")) do parts[#parts + 1] = "{" .. t .. "}" end
    template = table.concat(parts, ".")
  end
  return (tex_keep_macros(template):gsub("{([CSB])}", "\\twcr%1{}"))
end

local NUMBERING = {
  ["1"] = "arabic", a = "alph", A = "Alph", i = "roman", I = "Roman", ["*"] = "fnsymbol", ["一"] = "zhnumber",
}
local NUMBERING_ORDER = { "1", "a", "A", "i", "I", "*", "一" }

local function numbering(pattern, what)
  if NUMBERING[pattern] == nil then
    fail(what .. ": expected one of " .. table.concat(NUMBERING_ORDER, " ") .. ", got `" .. tostring(pattern) .. "`")
  end
  return NUMBERING[pattern]
end

local function numbering_page(pattern)
  return ({ ["1"] = "arabic", i = "roman", I = "Roman", a = "alph", A = "Alph" })[pattern] or "arabic"
end

local function parse_date(s)
  local parts = split(tostring(s), "-")
  if #parts ~= 3 then fail("date must be YYYY-MM-DD, got `" .. tostring(s) .. "`") end
  for i, x in ipairs(parts) do if x:match("^%d+$") then parts[i] = math.tointeger(tonumber(x)) end end
  return { year = parts[1], month = parts[2], day = parts[3] }
end

local function pad2(v) return math.type(v) == "integer" and string.format("%02d", v) or tostring(v) end

-- a built-in CSL style name: lowercase words joined by single hyphens
local function builtin_style_name(s)
  return s:match("^[a-z0-9%-]+$") ~= nil and not s:find("^%-") and not s:find("%-$") and not s:find("%-%-")
end

local function bool(v) return v == true and "1" or "0" end

local function bibliography_sources(cfg)
  local raw = cfg.bibliography.path
  local paths = type(raw) == "string" and { raw } or raw
  local out = {}
  for _, p in ipairs(paths) do
    local lower = p:lower()
    if not (ends_with(lower, ".bib") or ends_with(lower, ".json") or ends_with(lower, ".yml") or ends_with(lower, ".yaml")) then
      fail("bibliography.path: `" .. p .. "` must be .bib, Hayagriva/CSL .yml/.yaml, or CSL .json")
    end
    out[#out + 1] = (p:gsub("^/+", ""))
  end
  return out
end

-- ---- derived values ----

local function derive(cfg, resources)
  local d = {}
  local l, hd, s = cfg.layout, cfg.layout.heading, cfg.strings
  local zh = l.language == "chinese"
  if l.language ~= "chinese" and l.language ~= "english" then fail("layout.language: expected chinese or english") end

  -- text
  local fs = tonumber(l["font-size"])
  local lh = tonumber(l["line-height"])
  d.fs = num(fs)
  d.ls = num(fs * lh)
  d["fs-small"] = num(fs * 0.9)
  d["ls-small"] = num(fs * 0.9 * lh)
  d["fs-foot"] = num(fs * 0.8)
  d["ls-foot"] = num(fs * 0.8 * lh)
  local indent = l["first-line-indent"]
  if is_null(indent) then indent = zh and 2 or 1.5 end
  d.indent = num(indent) .. "em"
  -- Typst's spacing replaces the leading between paragraphs; LaTeX's parskip adds
  -- to it. `~` follows the line grid, while a number remains an independent
  -- override, so only its excess over normal leading is added.
  local leading = lh - 1
  local paragraph_spacing = is_null(l["par-spacing"]) and leading or tonumber(l["par-spacing"])
  d.parskip = num(math.max(0.0, paragraph_spacing - leading)) .. "em"
  d["title-spread"] = num(l["title-spread"]) .. "em"
  for _, side in ipairs { "top", "bottom", "left", "right" } do d["margin." .. side] = num(l.margin[side]) .. "cm" end

  -- fonts
  for _, key in ipairs { "font-latin", "font-cjk" } do
    local v = l[key]
    d[key] = is_list(v) and v or { v }
  end

  -- headings
  local ALIGN = { left = "\\raggedright", center = "\\centering", right = "\\raggedleft" }
  for i = 1, 4 do
    local size = tonumber(hd.size[i])
    d["heading.size." .. i] = num(size)
    d["heading.lead." .. i] = num(size * tonumber(hd["line-height"]))
    d["heading.above." .. i] = em_to_pt(hd["gap-above"][i], size)
    d["heading.below." .. i] = em_to_pt(hd["gap-below"][i], size)
    d["heading.gap." .. i] = em_to_pt(hd["number-gap"][i], size)
    local a = hd.align[i]
    if not ALIGN[a] then fail("layout.heading.align: expected left, center or right") end
    d["heading.align." .. i] = ALIGN[a]
  end
  d["heading.bold"] = hd.weight == "bold" and "1" or "0"

  -- captions
  for kind, pos in pairs(l["caption-position"]) do
    if pos ~= "top" and pos ~= "bottom" then fail("layout.caption-position." .. kind .. ": expected top or bottom") end
    d["caption." .. kind] = pos
  end

  -- numbering
  d["footnote-style"] = numbering(l["footnote-numbering"], "layout.footnote-numbering")
  d["equation-style"] = numbering(l["equation-numbering"], "layout.equation-numbering")
  d["footnote-per-chapter"] = bool(l["footnote-per-chapter"])
  d["equation-per-chapter"] = bool(l["equation-per-chapter"])
  d["first-line-indent-all"] = bool(l["first-line-indent-all"])
  d.justify = bool(l.justify)

  -- page number
  local pn = cfg["page-number"]
  if pn.position ~= "top" and pn.position ~= "bottom" then fail("page-number.position: expected top or bottom") end
  if pn.align ~= "left" and pn.align ~= "center" and pn.align ~= "right" then
    fail("page-number.align: expected left, center or right")
  end
  d["pn.position"] = pn.position
  d["pn.align"] = ({ left = "L", center = "C", right = "R" })[pn.align]
  if not is_null(pn.format) and pn.format ~= "" then
    local escaped = replace_plain(tex(pn.format), "\\{page\\}", "{page}")
    d["pn.format"] = fill(escaped, { page = "\\thepage{}" })
  else
    d["pn.format"] = ""
  end

  -- cross-ref
  local cr = cfg["cross-ref"]
  local style = not is_null(cr.numbering) and cr.numbering or (zh and "一" or "1")
  d["cr.style"] = numbering(style, "cross-ref.numbering")
  for _, key in ipairs { "chapter", "section", "subsection" } do
    if type(cr[key]) ~= "string" then fail("cross-ref." .. key .. ": expected a string") end
    d["cr." .. key] = cross_ref_format(cr[key])
  end

  -- outline
  local o = cfg.outline
  d["outline.title-size"] = num(o["title-size"])
  d["outline.title-lead"] = num(tonumber(o["title-size"]) * 1.2)
  for i = 1, 3 do d["outline.indent." .. i] = num(tonumber(o.indent) * i) .. "em" end
  d["outline.entry-gap"] = num(o["entry-gap"]) .. "em"
  d["outline.numbering.front"] = numbering_page(o["page-numbering"])
  d["outline.numbering.body"] = numbering_page(o["body-numbering"])

  -- cover geometry
  local cv = cfg.cover
  local cm = cv.margin
  local top = not is_null(cm.top) and cm.top or l.margin.top
  local left = not is_null(cm.left) and cm.left or l.margin.left
  local right = not is_null(cm.right) and cm.right or l.margin.right
  local bottom = not is_null(cm.bottom) and cm.bottom or top   -- mirrors its own top
  for side, v in pairs { top = top, bottom = bottom, left = left, right = right } do
    d["cover.margin." .. side] = num(v) .. "cm"
  end
  for k, v in pairs(cv.size) do
    d["cover.size." .. k] = num(v)
    d["cover.lead." .. k] = num(tonumber(v) + 0.5 * fs)   -- 1em line box + 0.5em leading
    d["cover.bold." .. k] = cv.weight[k] == "bold" and "1" or "0"
  end
  d["cover.gap.org-en"] = em_to_pt(cv.gap, cv.size["org-en"])
  d["cover.gap.university-en"] = em_to_pt(cv.gap, cv.size["university-en"])
  d["cover.flex"] = num(cv.flex)

  -- verification geometry
  local vf = cfg.verification
  local vg = vf.grid
  local body = tonumber(vf.size.body)
  d["verification.flex"] = num(vf.flex)
  d["verification.flex-end"] = num(vf["flex-end"])
  local total = 0
  for _, x in ipairs(vg.columns) do total = total + tonumber(x) end
  d["verification.col1"] = num(tonumber(vg.columns[1]) / total)
  d["verification.col2"] = num(tonumber(vg.columns[2]) / total)
  for i, r in ipairs(vg.rows) do d["verification.row." .. i] = em_to_pt(r, body) end
  d["verification.rule"] = num(tonumber(vg.rule) / 100)
  d["verification.rule-pair"] = num(tonumber(vg["rule-pair"]) / 100)
  d["verification.gutter"] = num(tonumber(vg.gutter) / 100)
  -- width of one paired rule, as a fraction of the right-hand column
  d["verification.pair"] = num((1 - tonumber(vg.gutter) / 100) / 2 * tonumber(vg["rule-pair"]) / 100)
  d["verification.director-indent"] = em_to_pt(vg["director-indent"], body)
  d["verification.dx"] = em_to_pt(vg["director-offset"][1], body)
  d["verification.dy"] = em_to_pt(vg["director-offset"][2], body)
  for k, v in pairs(vf.size) do
    d["verification.size." .. k] = num(v)
    d["verification.lead." .. k] = num(tonumber(v) + 0.5 * fs)
    d["verification.bold." .. k] = vf.weight[k] == "bold" and "1" or "0"
  end

  -- titles / sections
  for k, v in pairs(cfg.titles) do d["titles." .. k] = tex(v, true) end
  d["verification.title"] = tex(vf.title, true)
  d["bibliography.title"] = tex(cfg.bibliography.title, true)

  -- dates
  local date = parse_date(cfg.date)
  local oral = parse_date(cfg["oral-date"])
  local function roc(y)
    return math.type(y) == "integer" and tostring(y - s["era-offset"]) or "○○○"
  end
  local function month_name(month, names)
    return math.type(month) == "integer" and names[month] or tostring(month)
  end
  d["cover.date-zh"] = tex(fill(cv["date-zh"], {
    era = s.era, roc = roc(date.year), ["year-unit"] = s["year-unit"],
    month = pad2(date.month), ["month-unit"] = s["month-unit"],
  }))
  d["cover.date-en"] = tex(fill(cv["date-en"], {
    ["month-name"] = month_name(date.month, s.months), year = date.year,
  }))
  d["cover.advisor-zh"] = tex(fill(cv["advisor-zh"], {
    label = s["advisor-label"], advisor = cfg.advisor, doctor = s.doctor }))
  d["cover.advisor-en"] = tex(fill(cv["advisor-en"], {
    label = s["advisor-label-en"], advisor = cfg["advisor-en"], doctor = s["doctor-en"] }))
  d["verification.degree-line"] = tex(fill(vf["degree-line"], {
    university = cfg.university, institute = cfg.institute, degree = cfg.degree, type = cfg.type }))
  d["verification.statement"] = tex(fill(vf.statement, {
    author = cfg.author, id = cfg.id, university = cfg.university, institute = cfg.institute,
    degree = cfg.degree, type = cfg.type, roc = roc(oral.year), month = pad2(oral.month), day = pad2(oral.day),
  }))

  -- keywords
  local function join(items, sep)
    local out = {}
    for _, x in ipairs(items) do out[#out + 1] = tostring(x) end
    return table.concat(out, sep)
  end
  d["keywords.zh"] = tex(join(cfg.keywords, cfg.sections["keywords-sep"]))
  d["keywords.en"] = tex(join(cfg["keywords-en"], cfg.sections["keywords-sep-en"]))

  -- caption prefixes
  d["figure-name"] = tex(zh and s.figure or s["figure-en"])
  d["table-name"] = tex(zh and s.table or s["table-en"])

  -- watermark
  local w = cfg.watermark
  if not is_null(w.image) and w.image ~= "" then d["watermark.image"] = (w.image:gsub("^/+", "")) end
  d["watermark.width"] = num(tonumber(w.width) / 100)
  d["watermark.opacity"] = num(tonumber(w.opacity) / 100)
  -- the image carries no alpha, so a white veil washes it out
  d["watermark.veil"] = num(1 - tonumber(w.opacity) / 100)

  -- bibliography: citation-style-language reads .bib, CSL JSON/YAML and (once
  -- converted) Hayagriva; `resources` overrides the paths after that step
  local b = cfg.bibliography
  local sources = bibliography_sources(cfg)
  d["bibliography.sources"] = table.concat(sources, ",")
  d["bibliography.resources"] = table.concat(resources or sources, ",")
  local style = b.style
  if ends_with(style, ".csl") then
    local path = style:gsub("^/+", "")
    d["bibliography.style"], d["bibliography.style.custom"] = path, "1"
    d["bibliography.style.id"] = path:sub(1, -#".csl" - 1)   -- citation-style-language adds .csl
  elseif builtin_style_name(style) then
    d["bibliography.style"], d["bibliography.style.custom"] = style, "0"
    d["bibliography.style.id"] = CSL_STYLE_IDS[style] or style
  else
    fail("bibliography.style: `" .. style .. "` must be a built-in CSL style name "
      .. "(apa, ieee, chicago-author-date, ...) or a path to a .csl file")
  end
  d["bibliography.color"] = (b.color:gsub("^#+", ""))
  d["bibliography.full"] = bool(b.full)

  -- strings the class needs directly
  d["ch.pre"], d["ch.post"] = tex(s.chapter[1]), tex(s.chapter[2])
  d["se.pre"], d["se.post"] = tex(s.section[1]), tex(s.section[2])
  d["ch-en"], d["se-en"] = tex(s["chapter-en"]), tex(s["section-en"])
  d["subsection.mark"] = tex(s.subsection)
  d["appendix.pre"], d["appendix.post"] = tex(s.appendix[1]), tex(s.appendix[2])
  return d
end

-- ---- output ----

-- every leaf as {dotted key, scalar}; lists get .n and .1 .2 ... keys
local function flatten(value, prefix, out)
  out = out or {}
  if is_list(value) then
    out[#out + 1] = { prefix .. "n", #value }
    for i, v in ipairs(value) do flatten(v, prefix .. i .. ".", out) end
  elseif is_dict(value) then
    for _, k in ipairs(sorted_keys(value)) do flatten(value[k], prefix .. k .. ".", out) end
  elseif is_table(value) then
    -- an empty table: nothing to emit
  else
    out[#out + 1] = { prefix:sub(1, -2), value }
  end
  return out
end

local function emit(key, value)
  if is_null(value) then return nil end
  if type(value) == "boolean" then value = value and "1" or "0" end
  return "\\twcfg{" .. key .. "}{" .. tostring(value) .. "}"
end

local PLAIN = {
  "title", "title-en", "author", "author-en", "id", "advisor", "advisor-en",
  "university", "university-en", "college", "college-en", "institute",
  "institute-en", "degree", "degree-en", "type", "type-en",
}

local function render(cfg, resources)
  local lines = { "% generated by scripts/gen.lua from config.yml -- do not edit" }
  for _, k in ipairs(PLAIN) do
    if cfg[k] == nil then fail("config.yml: missing key `" .. k .. "`") end
    lines[#lines + 1] = emit("cfg." .. k, tex(cfg[k]))
  end
  -- every raw config value (numbers, positions, weights, ...) as-is
  local skip = set(PLAIN)
  for _, k in ipairs { "keywords", "keywords-en", "date", "oral-date", "school", "titles" } do skip[k] = true end
  for _, k in ipairs(sorted_keys(cfg)) do
    if not skip[k] then
      for _, kv in ipairs(flatten(cfg[k], k .. ".")) do
        local val = kv[2]
        if type(val) == "string" then val = tex(val) end
        local line = emit("cfg." .. kv[1], val)
        if line then lines[#lines + 1] = line end
      end
    end
  end
  local derived = derive(cfg, resources)
  for _, key in ipairs(sorted_keys(derived)) do
    local val = derived[key]
    if is_list(val) then
      for _, kv in ipairs(flatten(val, key .. ".")) do lines[#lines + 1] = emit("d." .. kv[1], kv[2]) end
    else
      local line = emit("d." .. key, val)
      if line then lines[#lines + 1] = line end
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

-- --------------------------------------------------------------------------
-- entry point
-- --------------------------------------------------------------------------

local function configure(root)
  ROOT = root
  SCHOOLS = root .. "/schools"
  I18N = root .. "/i18n"
  BUILD_DIR = root .. "/.tw-thesis-build"
end

local function run(config, out_path)
  local cfg = load_config(config)
  local sources = bibliography_sources(cfg)
  derive(cfg)   -- validate everything before touching the build directory
  local absolute_sources = {}
  for _, p in ipairs(sources) do absolute_sources[#absolute_sources + 1] = ROOT .. "/" .. p end
  local prepared = prepare_resources(absolute_sources, BUILD_DIR)
  local resources = {}
  for _, p in ipairs(prepared) do
    resources[#resources + 1] = p:sub(1, #ROOT + 1) == ROOT .. "/" and p:sub(#ROOT + 2) or p
  end
  local style = cfg.bibliography.style
  if ends_with(style, ".csl") then
    local file = style:gsub("^/+", "")
    if not is_file(ROOT .. "/" .. file) then fail("bibliography.style: " .. ROOT .. "/" .. file .. " not found") end
  end
  local out = render(cfg, resources)
  mkdir_p(dirname(out_path))
  write_if_changed(out_path, out)
end

gen.configure, gen.run, gen.load = configure, run, load_config
gen.derive, gen.render, gen.tex, gen.num = derive, render, tex, num
gen.hayagriva_to_csl, gen.classify_yaml, gen.prepare_resources = hayagriva_to_csl, classify_yaml, prepare_resources
gen.json_encode, gen.parse_yaml = json_encode, parse_yaml

local function main(argv)
  local script_dir = absolute(dirname(argv[0] or "scripts/gen.lua"))
  configure(dirname(script_dir))
  local config, out_path = ROOT .. "/config.yml", ROOT .. "/.tw-thesis-config.tex"
  local i = 1
  while argv[i] do
    if argv[i] == "-o" or argv[i] == "--out" then
      out_path = absolute(argv[i + 1] or fail("-o needs a path")); i = i + 2
    else
      config = absolute(argv[i]); i = i + 1
    end
  end
  local ok, err = pcall(run, config, out_path)
  if not ok then
    if type(err) == "table" and err.config_error then
      io.stderr:write("error: ", err.config_error, "\n")
      os.exit(1)
    end
    error(err, 0)
  end
end

-- run as a script, or `require` it from the tests
if arg and arg[0] and arg[0]:match("gen%.lua$") then
  main(arg)
end

return gen
