## What the Script Does
- Fetches all repositories from your organization or personal account
- Clones each repository temporarily
- Finds the workflow file and checks if it exists
- Uses sed to comment out the pull_request section (lines matching the pattern)
- Creates a new branch for the changes
- Commits and pushes the changes
- Creates a pull request for review
- Cleans up temporary files


#### What the sed command does:
```sed -i.bak '/pull_request:/,/^[[:space:]]*$/{
    /pull_request:/,/^[[:space:]]*branches:/s/^/# /
    /^[[:space:]]*branches:/,/^[[:space:]]*-.*\(main\|staging\)/{
        /^[[:space:]]*-.*\(main\|staging\)/s/^/# /
        /^[[:space:]]*branches:/s/^/# /
    }
}'
```
#### Breakdown:

```/pull_request:/,/^[[:space:]]*$/```  Finds the pull_request section until an empty line
```[[:space:]]*``` -Matches any amount of whitespace (spaces, tabs)

The nested patterns handle the branches: subsection and branch names with any indentation

This finds the section starting with   pull_request: and ending with       - staging and adds #  to the beginning of each line in that range.

Testing First
Test on a single repository first:
```
# Test with one repo
gh repo clone your-repo/test-repo
cd test-repo
```
Run the sed command manually to verify it works correctly
The script will create pull requests so you can review changes before merging. This gives you control over which repositories actually get the changes applied.