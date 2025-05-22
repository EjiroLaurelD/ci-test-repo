#!/bin/bash

# Configuration
ORGANIZATION="ejirolaureld"
WORKFLOW_FILE=".github/workflows/actions.yaml"
BRANCH_NAME="update-ci-workflow-$(date +%s)"  # Create unique branch name
COMMIT_MESSAGE="Comment out pull request step CI workflow"

# Disable git pager to prevent interactive prompts
export GIT_PAGER=""

# Get list of repositories
echo "Fetching repositories..."
repos=$(gh repo list "$ORGANIZATION" --limit 1000 --json name -q '.[].name' | grep -v "^$")
#repos="ci-test-repo"
# Convert to array
repo_array=()
while IFS= read -r line; do
    repo_array+=("$line")
done <<< "$repos"

echo "Found ${#repo_array[@]} repositories"

# Counter for tracking progress
counter=0
success_count=0
error_count=0

# Process each repository
for repo_name in "${repo_array[@]}"; do
    counter=$((counter + 1))
    echo "[$counter/${#repo_array[@]}] Processing: $ORGANIZATION/$repo_name"
    
    # Create temporary directory
    temp_dir="temp_$repo_name"
    
    # Clone repository (show errors)
    if gh repo clone "$ORGANIZATION/$repo_name" "$temp_dir"; then
        cd "$temp_dir"
        
        # Check if workflow file exists
        if [ -f "$WORKFLOW_FILE" ]; then
            echo "  Found workflow file: $WORKFLOW_FILE"
            
            # Show current content around pull_request (for debugging)
            echo "  Current pull_request section:"
            grep -A 5 -B 2 "pull_request:" "$WORKFLOW_FILE" || echo "  No pull_request section found"
            
            # Create new branch with unique name
            echo "  Creating branch: $BRANCH_NAME"
            if git checkout -b "$BRANCH_NAME"; then
                
                # sed command to handle different indentation
                sed -i.bak '/pull_request:/,/^[[:space:]]*$/{
                    /pull_request:/,/^[[:space:]]*branches:/s/^/# /
                    /^[[:space:]]*branches:/,/^[[:space:]]*-.*[main|staging]/{
                        /^[[:space:]]*-.*[main|staging]/s/^/# /
                        /^[[:space:]]*branches:/s/^/# /
                    }
                }' "$WORKFLOW_FILE"
                
                # Show what changed (non-interactive)
                echo "  Changes made:"
                git --no-pager diff HEAD "$WORKFLOW_FILE" | head -20
                
                # Check if changes were made
                if ! git diff --quiet "$WORKFLOW_FILE"; then
                    # Stage and commit changes
                    git add "$WORKFLOW_FILE"
                    git commit -m "$COMMIT_MESSAGE"
                    
                    # Push branch (show errors)
                    echo "  Pushing branch to origin..."
                    if git push origin "$BRANCH_NAME"; then
                        # Create pull request (show errors)
                        echo "  Creating pull request..."
                        pr_output=$(gh pr create \
                            --title "$COMMIT_MESSAGE" \
                            --body "Automated update to comment out pull_request triggers in CI workflow" 2>&1)
                        
                        if [ $? -eq 0 ]; then
                            echo "  ✅ Success: Created PR for $repo_name"
                            echo "  PR URL: $pr_output"
                            success_count=$((success_count + 1))
                        else
                            echo "  ❌ Error: Failed to create PR for $repo_name"
                            echo "  Error details: $pr_output"
                            error_count=$((error_count + 1))
                        fi
                    else
                        echo "  ❌ Error: Failed to push branch for $repo_name"
                        error_count=$((error_count + 1))
                    fi
                else
                    echo "  ⚠️  No changes needed for $repo_name (sed didn't match anything)"
                fi
            else
                echo "  ❌ Error: Failed to create branch for $repo_name"
                error_count=$((error_count + 1))
            fi
        else
            echo "  ⚠️  Workflow file not found in $repo_name"
        fi
        
        # Cleanup
        cd ..
        rm -rf "$temp_dir"
    else
        echo "  ❌ Error: Failed to clone $repo_name"
        error_count=$((error_count + 1))
    fi
    
    # Small delay to avoid rate limiting
    sleep 1
done

echo ""
echo "Summary:"
echo "  Total repositories: ${#repo_array[@]}"
echo "  Successful updates: $success_count"
echo "  Errors: $error_count"