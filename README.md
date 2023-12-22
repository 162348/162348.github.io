To add a new post,

1. select an appropriate subdirectory in directory `posts/`.
2. Write your post inside this sub-folder as a qmd file, perhaps with the aid of [Markdown Basics](https://quarto.org/docs/authoring/markdown-basics.html)
3. `git add` new files, `git commit -a` and `git push`. GitHub Action will automatically publish them for you.

To push a modification,

1. If you modified any code blocks, render the relevant file by `quarto render ./DD-MM-YYY`.
2. Otherwise, GitHub Action will automatically publish the modification.
3. Thus, just `git add` new files, `git commit -a` and `git push`.