module ProfileView

using Compose, Lazy, Requires

include("javascript.jl")
include("data.jl")
include("blink.jl")

githuburl(file, line) = "https://github.com/JuliaLang/julia/tree/$(Base.GIT_VERSION_INFO.commit)/base/$file#L$line"

function basepath(file)
  path = joinpath(JULIA_HOME,"..","share","julia","base",file) |> normpath
  isfile(path) || (path = nothing)
  return path
end

fullpath(file) = isabspath(string(file)) ? string(file) : basepath(string(file))

maprange(x1, x2, y1, y2, p) = (p-x1)/(x2-x1)*(y2-y1)+y1

fixedscale(node::ProfileTree) = ones(length(node.children))
# widthscale(node::ProfileTree) = childwidths(node)
widthscale(node::ProfileTree) = map(w -> maprange(0, 1, 1/5, 1, w), childwidths(node))

function fileattribute(li)
  svgattribute("data-file", "$(fullpath(li.file)):$(li.line)")
end

function render_(tree::ProfileTree; childscale = fixedscale, count = 0)
  widths = childwidths(tree)
  offsets = cumsum([0, widths[1:end-1]...])
  scale = childscale(tree)
  li = tree.data.line
  compose(context(),
          (context(), rectangle(),
           JS.framedata(li, tree.data.count/count),
           JS.frametooltip,
           svgclass("file-link"),
           fileattribute(li)),
          [compose(context(offsets[i], 1, widths[i], scale[i]),
                   render_(tree.children[i], childscale=childscale, count=count))
           for i = 1:length(tree.children)]...)
end

maxheight(node::ProfileTree; childscale = fixedscale) =
  isleaf(node) ? 1 :
    1 + maximum(childscale(node) .*
                  map(node->maxheight(node, childscale=childscale),
                      node.children))

render(tree::ProfileTree; childscale = widthscale) =
  compose(context(),
          (context(0,0,1,1/maxheight(tree, childscale = childscale)),
           render_(tree,childscale = childscale, count = tree.data.count),
           svgclass("tree")),
          (context(), rectangle(), svgclass("background")),
          JS.mapzoom, JS.mapdrag, JS.nonscalingstroke, JS.tooltip, JS.settooltip,
          svgclass("root"))

function Base.writemime(io::IO, ::MIME"text/html", tree::ProfileTree)
  write(io, "<style>",
        readstring(Pkg.dir("DevTools", "res", "profile.css")),
        "</style>")
  write(io, """
    <div class="profile">
      <div class="tooltip">
        <div><span class="func"></span> <span class="percent"></span></div>
        <div class="file"></div>
      </div>
  """)
  draw(SVGJS(io, 140mm, 190mm, false), render(tree))
  write(io, """
    </div>
  """)
end

end
