local M = {}

M.format_parentheses = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local lines = vim.api.nvim_buf_get_lines(0, row, row + 1, false)
  local line = lines[1]
  
  if not line then
    vim.notify("Could not get current line", vim.log.levels.WARN)
    return
  end
  
  -- Find first parenthesis in line
  local open_col = line:find("%(")
  if not open_col then
    vim.notify("No parenthesis found in current line", vim.log.levels.WARN)
    return
  end
  
  -- Get base indentation (everything before the opening parenthesis)
  local base_indent = line:sub(1, open_col - 1):match("^(%s*)")
  
  -- Determine if using tabs or spaces and the indent width
  local use_tabs = vim.bo.expandtab == false
  local indent_width = vim.bo.shiftwidth
  if indent_width == 0 then
    indent_width = vim.bo.tabstop
  end
  
  -- Create inner indent (one level deeper than base)
  local inner_indent
  if use_tabs then
    inner_indent = base_indent .. "\t"
  else
    inner_indent = base_indent .. string.rep(" ", indent_width)
  end
  
  -- Move cursor to that position
  vim.api.nvim_win_set_cursor(0, {row + 1, open_col - 1})
  
  -- Try tree-sitter approach
  local has_ts = pcall(require, 'nvim-treesitter.ts_utils')
  local has_parsers, parsers = pcall(require, 'nvim-treesitter.parsers')
  
  if has_ts and has_parsers and parsers.has_parser() then
    local success = M.format_with_treesitter(row, open_col, line, base_indent, inner_indent)
    if success then return end
  end
  
  -- Fallback to manual parsing
  M.format_manual(row, open_col, line, base_indent, inner_indent)
end

M.format_with_treesitter = function(row, open_col, line, base_indent, inner_indent)
  local node = vim.treesitter.get_node()
  if not node then
    return false
  end
  
  -- Find the closest parenthesized expression
  local target_node = nil
  local current = node
  
  while current do
    local type = current:type()
    local node_row = current:range()
    
    -- Check for various parenthesized node types
    if node_row == row and (
       type:match("parameters") or 
       type:match("arguments") or
       type:match("parenthesized") or
       type == "parameter_list" or
       type == "argument_list" or
       type == "formal_parameters" or
       type == "arguments" or
       type == "type_arguments") then
      target_node = current
      break
    end
    current = current:parent()
  end
  
  if not target_node then
    return false
  end
  
  local start_row, start_col, end_row, end_col = target_node:range()
  
  -- Get all parameter nodes
  local params = {}
  for child in target_node:iter_children() do
    local child_type = child:type()
    if child_type ~= "(" and 
       child_type ~= ")" and 
       child_type ~= "," and
       child_type ~= "comment" then
      local p_start_row, p_start_col, p_end_row, p_end_col = child:range()
      local param_lines = vim.api.nvim_buf_get_text(0, 
        p_start_row, p_start_col,
        p_end_row, p_end_col, {})
      local param_text = table.concat(param_lines, " "):match("^%s*(.-)%s*$")
      
      if param_text ~= "" then
        table.insert(params, param_text)
      end
    end
  end
  
  if #params == 0 then
    local result = {"(", base_indent .. ")"}
    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, result)
    return true
  end
  
  -- Build result with proper indentation
  local result = {}
  table.insert(result, "(")
  for i, param in ipairs(params) do
    local line_text = inner_indent .. param
    if i < #params then
      line_text = line_text .. ","
    end
    table.insert(result, line_text)
  end
  table.insert(result, base_indent .. ")")
  
  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, result)
  
  return true
end

M.format_manual = function(row, open_col, line, base_indent, inner_indent)
  -- Find matching closing parenthesis
  local depth = 0
  local close_col = nil
  for i = open_col, #line do
    local char = line:sub(i, i)
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
      if depth == 0 then
        close_col = i
        break
      end
    end
  end
  
  if not close_col then
    vim.notify("No matching closing parenthesis found", vim.log.levels.WARN)
    return
  end
  
  -- Extract content between parentheses
  local content = line:sub(open_col + 1, close_col - 1)
  content = content:match("^%s*(.-)%s*$")
  
  if content == "" then
    local result = {"(", base_indent .. ")"}
    vim.api.nvim_buf_set_text(0, row, open_col - 1, row, close_col, result)
    return
  end
  
  -- Split by comma (handling nested structures)
  local params = {}
  local current_param = ""
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0
  local in_string = false
  local string_char = nil
  
  for i = 1, #content do
    local char = content:sub(i, i)
    local prev_char = i > 1 and content:sub(i-1, i-1) or ""
    
    -- Handle strings (with escape sequences)
    if (char == '"' or char == "'" or char == "`") and prev_char ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
      current_param = current_param .. char
    -- Handle nested structures
    elseif not in_string then
      if char == "(" then
        paren_depth = paren_depth + 1
        current_param = current_param .. char
      elseif char == ")" then
        paren_depth = paren_depth - 1
        current_param = current_param .. char
      elseif char == "[" then
        bracket_depth = bracket_depth + 1
        current_param = current_param .. char
      elseif char == "]" then
        bracket_depth = bracket_depth - 1
        current_param = current_param .. char
      elseif char == "{" then
        brace_depth = brace_depth + 1
        current_param = current_param .. char
      elseif char == "}" then
        brace_depth = brace_depth - 1
        current_param = current_param .. char
      elseif char == "," and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
        -- Found a top-level separator
        local trimmed = current_param:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
          table.insert(params, trimmed)
        end
        current_param = ""
      else
        current_param = current_param .. char
      end
    else
      current_param = current_param .. char
    end
  end
  
  -- Add the last parameter
  local trimmed = current_param:match("^%s*(.-)%s*$")
  if trimmed ~= "" then
    table.insert(params, trimmed)
  end
  
  if #params == 0 then
    return
  end
  
  -- Build formatted result with proper indentation
  local result = {}
  table.insert(result, "(")
  for i, param in ipairs(params) do
    local line_text = inner_indent .. param
    if i < #params then
      line_text = line_text .. ","
    end
    table.insert(result, line_text)
  end
  table.insert(result, base_indent .. ")")
  
  -- Replace text
  vim.api.nvim_buf_set_text(0, row, open_col - 1, row, close_col, result)
end

return M
