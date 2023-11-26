To add a new post,

1. create a new sub-directory `DD-MM-YYYY-name` in directory `posts/`.
2. Write your post inside this sub-folder as a qmd file, with the aid of [Markdown Basics](https://quarto.org/docs/authoring/markdown-basics.html)
4. Compile the file just created, `quarto render ./DD-MM-YYY`.
5. `git add` new files, `git commit -a` and `git push`

To push a modification,

1. If you modified any code blocks, render the relevant file by `quarto render ./DD-MM-YYY`.
2. Otherwise, GitHub Action will automatically publish the modification.
3. Thus, just `git add` new files, `git commit -a` and `git push`