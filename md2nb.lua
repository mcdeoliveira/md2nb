-- This is a sample custom writer for pandoc, using Layout to
-- produce nicely wrapped output.

local layout = pandoc.layout
local text = pandoc.text
local type = pandoc.utils.type

local l = layout.literal

-- Table to store footnotes, so they can be included at the end.
local notes = pandoc.List()

-- Dispatch table for AST element writers
local dispatch = {}
local function write (elem, t, opts)
   if t == nil then
      t = '"Text"'
   end
   if type(elem) == 'Block' or type(elem) == 'Inline' then
      return (
	 dispatch[elem.t] or dispatch[type(elem)] or
	 error(('No function to convert %s (%s)'):format(elem.t, type(elem)))
      )(elem, t, opts)  -- call dispatch function with element
   elseif type(elem) == 'Inlines' then
      return 'Cell[TextData[{' .. layout.concat(elem:map(function(e,i) return write(e,t,opts) end), ', ') .. '}], ' .. t .. (opts ~= nil and ', ' .. opts or '') .. ']'
   elseif type(elem) == 'Blocks' then
      return layout.concat(elem:map(function(e,i) return write(e,t,opts) end), ',\n')
   end
   error('cannot convert unknown type: ' .. type(element))
end

local function escapeTeX(s)
   return s:gsub('\\', '\\\\')
end

local function escape(s)
   return s:gsub('"', '\\"'):gsub('’', "'")
end

function dispatch.Str(s)
   return '"' .. escape(s.text) .. '"'
end

function dispatch.Space()
   return '" "'
end

function dispatch.SoftBreak()
   return '" "'
end

function dispatch.LineBreak()
   return layout.cr
end

function dispatch.Emph(e)
   return 'StyleBox[Cell[TextData[{' .. write(e.content) .. '}]], FontSlant->"Italic"]'
end

function dispatch.Strong(s)
   return 'StyleBox[Cell[TextData[{' .. write(s.content) .. '}]], FontWeight->"Bold"]'
end

function dispatch.Subscript(s)
   return "~" .. write(s.content) .. "~"
end

function dispatch.Superscript(s)
   return "^" .. write(s.content) .. "^"
end

function dispatch.SmallCaps(s)
   return text.upper(s)
end

function dispatch.Strikeout(s)
   return 'Style[' .. write(s.content) .. ', Struckthrough]'
end

function dispatch.Link(link)
   local title = link.title == ''
      and ''
      or ' "' .. link.title:gsub('"', '\\"') .. '"'
   -- return write(link.content) .. ', " ", ' ..
   --    '"(* ' .. l(link.target .. title) .. ' *)"'
   return 'Cell[Hyperlink[' .. dispatch.Emph(link) .. ', "' ..
      l(link.target:gsub('#', '')) .. '"]]'
end

function dispatch.Image(img)
   local title = img.title == ''
      and ''
      or ' ' .. title:gsub('"', '\\"')
   return '!' .. write(pandoc.Inlines(img.content)):brackets() .. l(img.src .. title):parens()
end

function dispatch.Code(code)
   return 'Cell[BoxData[FormBox[RowBox[{"' .. code.text .. '"}], TraditionalForm]]]'
end

function dispatch.Math (m)
   if m.mathtype == 'InlineMath' then
      return 'Cell[ToExpression["' .. l(escapeTeX(m.text)) .. '", TeXForm]]'
   else
      return 'Cell[ToExpression["' .. l(escapeTeX(m.text)) .. '", TeXForm]]'
   end
end

function dispatch.Quoted(q)
   return '"\\"", ' .. write(q.content) .. ', "\\""'
end

function dispatch.Note(n)
   notes:insert(write(n.content))
   return '(* See [^' .. tostring(#notes) .. '] *)'
end

function dispatch.Span(s)
   return write(s.content)
end

function dispatch.RawInline(raw)
   return raw.format == "markdown" and raw.text or ''
end

function dispatch.Cite (cite)
   return write(cite.content)
end

function dispatch.Plain(p)
   return write(p.content)
end

function dispatch.Para(p, t, opts)
   return write(p.content, t, opts)
end

function dispatch.Header(header)
   local levels = {
      '"Section"', '"Subsection"', '"Subsubsection"', '"Text"', '"Text"'
   }
   return write(header.content, levels[header.level])
end

function dispatch.BlockQuote(bq)
   return write(bq.content,
		'"Text"',
		'CellMargins->{{60,0},{0,0}}, Background->GrayLevel[0.85]')
end

function dispatch.HorizontalRule()
   return string.rep('- ', 7) .. '-'
end

function dispatch.LineBlock(ls)
   return '<div style="white-space: pre-line;">'
      .. layout.concat(ls.content:map(write), layout.cr)
      .. '</div>'
end

function dispatch.CodeBlock(cb, t, opts)
   return 'Cell["' .. l(cb.text) .. '", ' ..
      (cb.classes[1] == 'output' and '"Output"' or '"Input"') ..
      (opts ~= nil and ', ' .. opts or '') .. ']'
end

function dispatch.BulletList(blist)
   local result = pandoc.List()
   for i, item in ipairs(blist.content) do
      result:insert('Cell[TextData[{' .. write(item) .. '}], "Item"]')
   end
   return layout.concat(result, ",\n")
end

function dispatch.OrderedList(olist)
   local result = pandoc.List()
   for i, item in ipairs(olist.content) do
      result:insert('Cell[TextData[{' .. write(item) .. '}], "ItemNumbered"]')
   end
   return layout.concat(result, ",\n")
end

function dispatch.DefinitionList(dlist)
   local result = pandoc.List()
   for i, item in ipairs(dlist.content) do
      local key = write(item[1])
      local value = layout.concat(
	 item[2]:map(write),
	 layout.blankline
      )
      result:insert(key / value:hang(4, ':   '))
   end
   return layout.concat(result, layout.blankline)
end

function dispatch.Table(tbl)
   return l'TABLE NOT CONVERTED'
end

function dispatch.RawBlock(raw)
   return raw.format == 'markdown' and raw.text or layout.empty
end

function dispatch.Div(div)
   return write(div.content)
end

Extensions = {
  smart = false,
  citations = false,
  foobar = false
}

function Writer(doc, opts)
   local buffer = pandoc.List()
   buffer:insert(write(doc.blocks))
   for i, note in ipairs(notes) do
      buffer:insert(
	 ',' .. layout.cr ..
	 'Cell["(* [^' .. tostring(i) .. ']: *)", "Text"],' .. layout.cr ..
	 note
      )
   end
   local body = 'Notebook[{\n' ..
      layout.concat(buffer, layout.cr) .. layout.cr ..
      '}]'

   return body:render()
end
