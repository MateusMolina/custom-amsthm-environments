
-- Custom amsthm environments extension for Quarto
-- Allows defining custom theorem-like environments using crossref metadata

local custom_amsthm_envs = {}
local amsthm_counters = {}
local current_counters = {}
local section_counters = {}
local current_section = nil
local current_file = nil
local new_ids_this_chapter = {}
local state_file = nil
local is_book = false

function string_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 1000000
  end
  return hash
end

function read_state()
  local file = io.open(state_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    if content ~= "" then
      local func = load("return " .. content)
      if func then
        return func()
      end
    end
  end
  return {counters = {}, values = {}, files = {}}
end

function serialize_table(tbl, indent)
  indent = indent or 0
  local indent_str = string.rep("  ", indent)
  local next_indent_str = string.rep("  ", indent + 1)
  
  if type(tbl) == "string" then
    return string.format("%q", tbl)
  elseif type(tbl) ~= "table" then
    return tostring(tbl)
  end
  
  local parts = {}
  for k, v in pairs(tbl) do
    local key_str = type(k) == "string" 
      and string.format("[%q]", k) 
      or "[" .. tostring(k) .. "]"
    table.insert(parts, next_indent_str .. key_str .. " = " .. serialize_table(v, indent + 1))
  end
  
  if #parts == 0 then
    return "{}"
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent_str .. "}"
end

function write_state()
  os.execute("mkdir -p .quarto")
  
  local files = {}
  for key, env in pairs(custom_amsthm_envs) do
    if current_counters[key] then
      files[key] = {}
      for id, _ in pairs(current_counters[key]) do
        local file_for_id
        if new_ids_this_chapter[key] and new_ids_this_chapter[key][id] then
          file_for_id = current_file or ""
        else
          file_for_id = (env.files and env.files[id]) or ""
        end
        files[key][id] = file_for_id
      end
    end
  end
  
  local state = {
    counters = amsthm_counters,
    values = current_counters,
    files = files
  }
  
  local file = io.open(state_file, "w")
  if file then
    file:write(serialize_table(state) .. "\n")
    file:close()
  end
end

function process_custom_amsthm(meta)
  local project_id = "default"
  if meta.book and meta.book.title then
    project_id = pandoc.utils.stringify(meta.book.title)
    is_book = true
  elseif meta.title then
    project_id = pandoc.utils.stringify(meta.title)
  end
  state_file = string.format(".quarto/amsthm-state-%d.lua", string_hash(project_id))
  
  if PANDOC_STATE and PANDOC_STATE.output_file then
    current_file = PANDOC_STATE.output_file
  end
  
  -- Extract chapter number from Span with class "chapter-number" in title
  if meta.title then
    for i = 1, #meta.title do
      local elem = meta.title[i]
      if elem and elem.t == "Span" and elem.classes then
        for _, cls in ipairs(elem.classes) do
          if cls == "chapter-number" then
            current_section = pandoc.utils.stringify(elem)
            break
          end
        end
        if current_section then break end
      end
    end
  end
  
  -- Reset state file on first chapter
  if not current_section or current_section == "1" then
    local file = io.open(state_file, "w")
    if file then
      file:write(serialize_table({counters = {}, values = {}, files = {}}) .. "\n")
      file:close()
    end
  end
  
  local previous_state = read_state()
  
  if meta["custom-amsthm"] then
    for _, custom in ipairs(meta["custom-amsthm"]) do
      local key = pandoc.utils.stringify(custom.key)
      local name = pandoc.utils.stringify(custom.name or key)
      local reference_prefix = pandoc.utils.stringify(custom["reference-prefix"] or name)
      local latex_name = pandoc.utils.stringify(custom["latex-name"] or name:lower())
      local numbered = custom.numbered == nil or custom.numbered -- default to true
      -- Get numbering style: "section" (default) or "global"
      local numbering_style = pandoc.utils.stringify(custom["numbering-style"] or "section")
      
      custom_amsthm_envs[key] = {
        name = name,
        reference_prefix = reference_prefix,
        latex_name = latex_name,
        numbered = numbered,
        numbering_style = numbering_style,
        files = (previous_state.files and previous_state.files[key]) or {}
      }
      
      -- For global numbering, restore counter from previous state
      if numbering_style == "global" and previous_state.counters[key] then
        amsthm_counters[key] = previous_state.counters[key]
      else
        amsthm_counters[key] = 0
      end
      
      current_counters[key] = previous_state.values[key] or {}
      section_counters[key] = {}
      
      if not meta.crossref then
        meta.crossref = {}
      end
      -- Add custom crossref type
      meta.crossref[key .. "-title"] = pandoc.MetaInlines({pandoc.Str(name)})
      meta.crossref[key .. "-prefix"] = pandoc.MetaInlines({pandoc.Str(reference_prefix)})
    end
  end
  
  return meta
end

function generate_latex_headers()
  local headers = {}
  
  for key, env in pairs(custom_amsthm_envs) do
    local latex_env
    if env.numbered then
      if env.numbering_style == "section" then
        -- In books, number within chapters; in articles, number within sections
        if is_book then
          latex_env = "\\newtheorem{" .. env.latex_name .. "}{" .. env.name .. "}[chapter]"
        else
          latex_env = "\\newtheorem{" .. env.latex_name .. "}{" .. env.name .. "}[section]"
        end
      else
        latex_env = "\\newtheorem{" .. env.latex_name .. "}{" .. env.name .. "}"
      end
    else
      latex_env = "\\newtheorem*{" .. env.latex_name .. "}{" .. env.name .. "}"
    end
    table.insert(headers, latex_env)
  end
  
  if #headers > 0 then
    return "\\usepackage{amsthm}\n" .. table.concat(headers, "\n")
  end
  return ""
end

function track_section_header(header)
  if header.level == 2 and header.attributes and header.attributes["number"] then
    local section_number = header.attributes["number"]
    -- Extract chapter number (e.g., "2" from "2.1")
    local chapter_num = section_number:match("^(%d+)%.")
    if chapter_num and chapter_num ~= current_section then
      current_section = chapter_num
      for key, env in pairs(custom_amsthm_envs) do
        if env.numbering_style == "section" then
          section_counters[key][current_section] = 0
        end
      end
    end
  end
  return header
end

function handle_amsthm_div(div)
  local id = div.identifier
  if id == "" then
    return div
  end
  
  -- Check if this div has an ID that matches any of our custom environments
  for key, env in pairs(custom_amsthm_envs) do
    local prefix = key .. "-"
    if id:sub(1, #prefix) == prefix then
      local label = ""
      local current_number = ""
      local title = ""
      local content_without_title = {}
      
      if env.numbered then
        if env.numbering_style == "section" and current_section then
          section_counters[key][current_section] = (section_counters[key][current_section] or 0) + 1
          current_number = current_section .. "." .. tostring(section_counters[key][current_section])
        else
          -- Global numbering
          amsthm_counters[key] = amsthm_counters[key] + 1
          current_number = tostring(amsthm_counters[key])
        end
        current_counters[key][id] = current_number
        
        -- Track new IDs for file mapping
        if not new_ids_this_chapter[key] then
          new_ids_this_chapter[key] = {}
        end
        new_ids_this_chapter[key][id] = true
        label = "\\label{" .. id .. "}"
      end
      
      -- Extract title from first header (## Title)
      for i, block in ipairs(div.content) do
        if i == 1 and block.t == "Header" and block.level == 2 then
          title = " (" .. pandoc.utils.stringify(block.content) .. ")"
        else
          table.insert(content_without_title, block)
        end
      end
      
      local latex_begin
      if title ~= "" then
        -- Strip parentheses: " (Title)" -> "Title"
        latex_begin = "\\begin{" .. env.latex_name .. "}[" .. title:gsub("^ %(", ""):gsub("%)$", "") .. "]" .. label
      else
        latex_begin = "\\begin{" .. env.latex_name .. "}" .. label
      end
      local latex_end = "\\end{" .. env.latex_name .. "}"
      
      -- For LaTeX output
      if FORMAT:match("latex") then
        local content = {}
        table.insert(content, pandoc.RawBlock("latex", latex_begin))
        for _, block in ipairs(content_without_title) do
          table.insert(content, block)
        end
        table.insert(content, pandoc.RawBlock("latex", latex_end))
        return content
      else
        -- For HTML output, create a styled div matching Quarto's built-in format
        local html_title = env.name
        if env.numbered then
          html_title = html_title .. " " .. current_number
        end
        if title ~= "" then
          html_title = html_title .. title
        end
        
        -- Preserve original classes and add "theorem" class
        local html_classes = {"theorem"}
        if div.classes then
          for _, cls in ipairs(div.classes) do
            table.insert(html_classes, cls)
          end
        end
        
        local content = {}
        
        -- Create the first paragraph with theorem title span and content
        if #content_without_title > 0 and content_without_title[1].t == "Para" then
          local first_para = content_without_title[1]
          local title_span = pandoc.Span(
            {pandoc.Strong({pandoc.Str(html_title)})},
            {class = "theorem-title"}
          )
          
          local new_content = {title_span, pandoc.Space()}
          for _, inline in ipairs(first_para.content) do
            table.insert(new_content, inline)
          end
          
          table.insert(content, pandoc.Para(new_content))
          
          for i = 2, #content_without_title do
            table.insert(content, content_without_title[i])
          end
        else
          local title_span = pandoc.Span(
            {pandoc.Strong({pandoc.Str(html_title)})},
            {class = "theorem-title"}
          )
          table.insert(content, pandoc.Para({title_span}))
          
          for _, block in ipairs(content_without_title) do
            table.insert(content, block)
          end
        end
        
        return pandoc.Div(content, pandoc.Attr(id, html_classes))
      end
    end
  end
  return div
end

function handle_amsthm_cite(cite)
  for i, citation in ipairs(cite.citations) do
    local id = citation.id
    for key, env in pairs(custom_amsthm_envs) do
      local prefix = key .. "-"
      if id:sub(1, #prefix) == prefix then
        -- Check if we have this ID in our current counters
        if current_counters[key][id] then
          if FORMAT:match("latex") then
            return pandoc.RawInline("latex", env.reference_prefix .. "~\\ref{" .. id .. "}")
          else
            local counter_val = current_counters[key][id]
            
            -- Include file name for cross-chapter references
            local href = "#" .. id
            local ref_file = env.files and env.files[id]
            if ref_file and ref_file ~= "" and ref_file ~= current_file then
              -- Cross-chapter reference - include the file name
              href = ref_file .. "#" .. id
            end
            
            return pandoc.Link(
              {pandoc.Str(env.reference_prefix), pandoc.Str("\u{00A0}"), pandoc.Str(counter_val)}, 
              href, 
              "", 
              {class = "quarto-xref"}
            )
          end
        end
        -- If we don't have the counter value, it might be a cross-chapter reference
        -- Let Quarto's crossref system handle it by not processing this cite
        return cite
      end
    end
  end
  return cite
end

-- Main filter functions
return {
  {
    Meta = function(meta)
      process_custom_amsthm(meta)
      
      -- Add LaTeX headers for custom environments
      if FORMAT:match("latex") then
        local latex_headers = generate_latex_headers()
        if latex_headers ~= "" then
          if meta["header-includes"] then
            if type(meta["header-includes"]) == "table" then
              table.insert(meta["header-includes"], pandoc.RawBlock("latex", latex_headers))
            else
              meta["header-includes"] = {meta["header-includes"], pandoc.RawBlock("latex", latex_headers)}
            end
          else
            meta["header-includes"] = pandoc.RawBlock("latex", latex_headers)
          end
        end
      end
      
      return meta
    end
  },
  {
    -- First pass: track headers and number divs
    Header = track_section_header,
    Div = handle_amsthm_div
  },
  {
    -- Second pass: handle cross-references (after counters are built)
    Cite = handle_amsthm_cite
  },
  {
    -- Final pass: save state for next chapter
    Pandoc = function(doc)
      write_state()
      return doc
    end
  }
}
