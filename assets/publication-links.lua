-- Keep the publication page buttons in sync with its YAML metadata.
function Pandoc(doc)
  if not quarto.doc.is_format("html") then
    return nil
  end

  local pub = doc.meta.pub or {}
  local citation = doc.meta.citation or {}
  local buttons = pandoc.List()

  local function add_button(url, label, icon, style)
    if not url then
      return
    end
    local target = pandoc.utils.stringify(url)
    if target == "" then
      return
    end
    if #buttons > 0 then
      buttons:insert(pandoc.Space())
    end
    buttons:insert(pandoc.Link({
      pandoc.RawInline("html", '<i class="' .. icon .. '" aria-hidden="true"></i>'),
      pandoc.Space(),
      pandoc.Str(label)
    }, target, "", pandoc.Attr("", {"btn", style, "btn-sm"}, {
      target = "_blank",
      rel = "noopener noreferrer"
    })))
  end

  add_button(pub["arxiv-url"], "arXiv", "ai ai-arxiv", "btn-secondary")
  add_button(pub["github-url"], "GitHub", "bi bi-github", "btn-dark")
  add_button(pub.pdf, "PDF", "bi bi-file-earmark-pdf", "btn-pdf")
  add_button(citation.url, "DOI", "ai ai-doi", "btn-primary")

  return doc:walk({
    Div = function(div)
      if div.classes:includes("pub-links") then
        div.content = {pandoc.Plain(buttons)}
        return div
      end
    end
  })
end
