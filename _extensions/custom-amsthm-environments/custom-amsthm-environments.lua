
-- Custom amsthm environments extension for Quarto
-- Allows defining custom theorem-like environments using crossref metadata

local custom_amsthm_envs = {}
local amsthm_counters = {}
local current_counters = {}
local section_counters = {}  -- Track counters per section for section-based numbering
local current_section = nil   -- Track current section number
local state_file = nil  -- Will be set based on project

-- Simple hash function for strings
function string_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 1000000
  end
  return hash
end

-- Function to read state from file
function read_state()
  local file = io.open(state_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    if content and content ~= "" then
      -- Parse JSON manually (simple parsing for our use case)
      local state = {counters = {}, values = {}}
      
      -- Extract global counters
      local counters_section = content:match('"counters"%s*:%s*{([^}]+)}')
      if counters_section then
        for key, value in counters_section:gmatch('"([^"]+)"%s*:%s*(%d+)') do
          state.counters[key] = tonumber(value)
        end
      end
      
      -- Extract counter values (id -> number mappings)
      local values_section = content:match('"values"%s*:%s*{(.+)}%s*}%s*$')
      if values_section then
        for key_section in values_section:gmatch('"([^"]+)"%s*:%s*{([^}]+)}') do
          local key = key_section
          local values_str = values_section:match('"' .. key .. '"%s*:%s*{([^}]+)}')
          if values_str then
            state.values[key] = {}
            for id, num in values_str:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
              state.values[key][id] = num
            end
          end
        end
      end
      
      return state
    end
  end
  return {counters = {}, values = {}}
end

-- Function to write state to file
function write_state()
  -- Create directory if it doesn't exist
  os.execute("mkdir -p .quarto")
  
  local file = io.open(state_file, "w")
  if file then
    file:write("{\n")
    
    -- Write global counters
    file:write('  "counters": {\n')
    local first = true
    for key, counter in pairs(amsthm_counters) do
      if not first then
        file:write(",\n")
      end
      file:write(string.format('    "%s": %d', key, counter))
      first = false
    end
    file:write("\n  },\n")
    
    -- Write counter values (id -> number mappings)
    file:write('  "values": {\n')
    first = true
    for key, values in pairs(current_counters) do
      if not first then
        file:write(",\n")
      end
      file:write(string.format('    "%s": {', key))
      local first_val = true
      for id, num in pairs(values) do
        if not first_val then
          file:write(", ")
        end
        file:write(string.format('"%s": "%s"', id, num))
        first_val = false
      end
      file:write("}")
      first = false
    end
    file:write("\n  }\n")
    
    file:write("}\n")
    file:close()
  end
end

-- Function to process metadata and extract custom amsthm environments
function process_custom_amsthm(meta)
  -- Set state file path based on project (use book title or current directory)
  local project_id = "default"
  if meta.book and meta.book.title then
    project_id = pandoc.utils.stringify(meta.book.title)
  elseif meta.title then
    project_id = pandoc.utils.stringify(meta.title)
  end
  local hash = string_hash(project_id)
  state_file = string.format(".quarto/amsthm-state-%d.json", hash)
  
  -- Extract chapter number from title metadata if in book mode
  -- Look for Span with class "chapter-number" in the title
  local chapter_num = nil
  if meta.title then
    -- Iterate through title inlines looking for chapter-number span
    for i = 1, #meta.title do
      local elem = meta.title[i]
      if elem and elem.t == "Span" and elem.classes then
        for _, cls in ipairs(elem.classes) do
          if cls == "chapter-number" then
            chapter_num = pandoc.utils.stringify(elem)
            current_section = chapter_num
            break
          end
        end
        if chapter_num then break end
      end
    end
    
    -- Fallback: try extracting from stringified title (less robust)
    if not chapter_num then
      local title_str = pandoc.utils.stringify(meta.title)
      chapter_num = title_str:match("^(%d+)")
      if chapter_num then
        current_section = chapter_num
      end
    end
  end
  
  -- Reset state file if this is the first chapter (chapter 1) or if no chapter number
  -- This ensures we start fresh for each book render
  if not chapter_num or chapter_num == "1" then
    -- Clear the state file for a fresh start
    local file = io.open(state_file, "w")
    if file then
      file:write('{"counters": {}, "values": {}}\n')
      file:close()
    end
  end
  
  -- Read previous state for global counters
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
        numbering_style = numbering_style
      }
      
      -- Initialize counters
      -- For global numbering, start from previous state
      if numbering_style == "global" and previous_state.counters[key] then
        amsthm_counters[key] = previous_state.counters[key]
      else
        amsthm_counters[key] = 0
      end
      
      -- Load previous counter values for cross-references
      if previous_state.values[key] then
        current_counters[key] = previous_state.values[key]
      else
        current_counters[key] = {}
      end
      
      section_counters[key] = {}  -- Track section-based counters
      
      -- Register with Quarto's crossref system
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

-- Function to generate LaTeX headers for custom environments
function generate_latex_headers()
  local headers = {}
  
  for key, env in pairs(custom_amsthm_envs) do
    if env.numbered then
      if env.numbering_style == "section" then
        -- Section-based numbering
        table.insert(headers, "\\newtheorem{" .. env.latex_name .. "}{" .. env.name .. "}[section]")
      else
        -- Global numbering 
        table.insert(headers, "\\newtheorem{" .. env.latex_name .. "}{" .. env.name .. "}")
      end
    else
      table.insert(headers, "\\newtheorem*{" .. env.latex_name .. "}{" .. env.name .. "}")
    end
  end
  
  if #headers > 0 then
    return "\\usepackage{amsthm}\n" .. table.concat(headers, "\n")
  else
    return ""
  end
end

-- Function to track section headers for section-based numbering
function track_section_header(header)
  -- Extract chapter number from level 2 headers in book format
  -- In books, chapters are separate files and sections are level 2 headers
  if header.level == 2 and header.attributes and header.attributes["number"] then
    local section_number = header.attributes["number"]
    -- Extract the chapter number (e.g., "2" from "2.1")
    local chapter_num = section_number:match("^(%d+)%.")
    if chapter_num and chapter_num ~= current_section then
      current_section = chapter_num
      -- Reset section-based counters when entering a new chapter
      for key, env in pairs(custom_amsthm_envs) do
        if env.numbering_style == "section" then
          section_counters[key][current_section] = 0
        end
      end
    end
  end
  return header
end

-- Function to handle custom amsthm divs
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
      
      -- Handle numbering and cross-references
      if env.numbered then
        if env.numbering_style == "section" and current_section then
          -- Section-based numbering
          section_counters[key][current_section] = (section_counters[key][current_section] or 0) + 1
          local section_counter = section_counters[key][current_section]
          current_number = current_section .. "." .. tostring(section_counter)
        else
          -- Global numbering
          amsthm_counters[key] = amsthm_counters[key] + 1
          current_number = tostring(amsthm_counters[key])
        end
        current_counters[key][id] = current_number
        label = "\\label{" .. id .. "}"
      end
      
      -- Extract title from first header (## Title) and prepare content
      for i, block in ipairs(div.content) do
        if i == 1 and block.t == "Header" and block.level == 2 then
          -- Extract title from the header
          title = " (" .. pandoc.utils.stringify(block.content) .. ")"
          -- Skip this header in the content
        else
          table.insert(content_without_title, block)
        end
      end
      
      -- Create LaTeX environment
      local latex_begin
      if title ~= "" then
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
        local html_class = "theorem"
        local html_title = env.name
        if env.numbered then
          html_title = html_title .. " " .. current_number
        end
        if title ~= "" then
          html_title = html_title .. title
        end
        
        local content = {}
        
        -- Create the first paragraph with theorem title span and content
        if #content_without_title > 0 and content_without_title[1].t == "Para" then
          -- If first block is a paragraph, merge the title with it
          local first_para = content_without_title[1]
          local title_span = pandoc.Span(
            {pandoc.Strong({pandoc.Str(html_title)})},
            {class = "theorem-title"}
          )
          
          -- Create new paragraph content with title span first
          local new_content = {title_span, pandoc.Space()}
          for _, inline in ipairs(first_para.content) do
            table.insert(new_content, inline)
          end
          
          table.insert(content, pandoc.Para(new_content))
          
          -- Add remaining blocks
          for i = 2, #content_without_title do
            table.insert(content, content_without_title[i])
          end
        else
          -- If no content or first block is not paragraph, create title-only paragraph
          local title_span = pandoc.Span(
            {pandoc.Strong({pandoc.Str(html_title)})},
            {class = "theorem-title"}
          )
          table.insert(content, pandoc.Para({title_span}))
          
          -- Add all content blocks
          for _, block in ipairs(content_without_title) do
            table.insert(content, block)
          end
        end
        
        return pandoc.Div(content, {class = html_class, id = id})
      end
    end
  end
  return div
end

-- Function to handle cross-references to custom amsthm environments
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
            -- For HTML, create a link matching Quarto's built-in format
            local counter_val = current_counters[key][id]
            return pandoc.Link(
              {pandoc.Str(env.reference_prefix), pandoc.Str("\u{00A0}"), pandoc.Str(counter_val)}, 
              "#" .. id, 
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
