# This is the root of a git subtree.
The directory sub-hierarchy rooted here is a git subtree of https://github.com/nosnhojn/svunit-code.git

It is incorporated here using a git subtree 
Read more about git subtree's here: https://www.atlassian.com/git/tutorials/git-subtree

### Commands used to create this sub-tree:
(From top of s2i-fpga hierarchy, with a clean repo)
git remote add -f svunit https://github.com/nosnhojn/svunit-code.git
git subtree add --prefix tools/svunit svunit master --squash

### To update sub-tree at a later date:
git fetch svunit master
git subtree pull --prefix tools/svunit svunit master --squash
