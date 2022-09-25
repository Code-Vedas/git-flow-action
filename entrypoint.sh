#!/usr/bin/env bash 
set -o pipefail

echo -e "GIT Flow Action\n\r"
echo -e "GIT Version: $(git --version)"
echo -e "GIT Flow Version: $(git flow version)\n\r"

BOT_NAME=${INPUT_BOT_NAME:-"git-flow-bot"}
BOT_EMAIL=${INPUT_BOT_EMAIL:-"gitflow-bot@codevedas.com"}
TRIGGER_CMD=${INPUT_TRIGGER_CMD:-"/gitflow"}
ALLOWED_AUTHORS=${INPUT_ALLOWED_AUTHORS:-""}
DEVELOP_BRANCH=${INPUT_DEVELOP_BRANCH:-"develop"}
PRODUCTION_BRANCH=${INPUT_PRODUCTION_BRANCH:-"master"}
FEATURE_BRANCH_PREFIX=${INPUT_FEATURE_BRANCH_PREFIX:-"feature/"}
RELEASE_BRANCH_PREFIX=${INPUT_RELEASE_BRANCH_PREFIX:-"release/"}
HOTFIX_BRANCH_PREFIX=${INPUT_HOTFIX_BRANCH_PREFIX:-"hotfix/"}
BUGFIX_BRANCH_PREFIX=${INPUT_BUGFIX_BRANCH_PREFIX:-"bugfix/"}
VERSION_TAG_PREFIX=${INPUT_VERSION_TAG_PREFIX:-"v"}
COMMENT_AUTHOR=${INPUT_COMMENT_AUTHOR:-}
COMMENT_BODY=${INPUT_COMMENT_BODY:-}
COMMENT_ID=${INPUT_COMMENT_ID:-}
BRANCH_NAME=${INPUT_BRANCH_NAME:-}
ISSUE_NUMBER=${INPUT_ISSUE_NUMBER:-}
MERGEABLE=${INPUT_MERGEABLE:-"false"}
IS_DRAFT=${INPUT_IS_DRAFT:-"false"}
MERGE_STATE_STATUS=${INPUT_MERGE_STATE_STATUS:-}

set_gitflow_config() {
    git config --global gitflow.branch.master $PRODUCTION_BRANCH
    git config --global gitflow.branch.develop $DEVELOP_BRANCH
    git config --global gitflow.prefix.feature $FEATURE_BRANCH_PREFIX
    git config --global gitflow.prefix.bugfix $BUGFIX_BRANCH_PREFIX
    git config --global gitflow.prefix.release $RELEASE_BRANCH_PREFIX
    git config --global gitflow.prefix.hotfix $HOTFIX_BRANCH_PREFIX
    git config --global gitflow.prefix.versiontag $VERSION_TAG_PREFIX
}

gitflow_init() {
    git config --global user.email "$BOT_EMAIL"
    git config --global user.name "$BOT_NAME"
    set_gitflow_config
    git flow init -fd
}


post_message_to_pr() {
    echo "Posting message to PR"
    curl -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/json" -d "{\"body\": \"$1\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments" --silent --output /dev/null
}

process_issue_comment() {
    # check if comment message is empty
    if [ -z "$COMMENT_BODY" ]; then
        echo "[SKIPPING] Comment Message is empty"
        return 1
    fi

    # check if COMMENT_BODY starts with TRIGGER_CMD
    if [[ "$COMMENT_BODY" != "$TRIGGER_CMD"* ]]; then
        echo "[SKIPPING] Comment Message does not start with $TRIGGER_CMD"
        return 1
    fi

    # extract cmd from COMMENT_BODY
    export GIT_FLOW_CMD=$(echo "$COMMENT_BODY" | cut -d' ' -f2)

    # check if GIT_FLOW_CMD is empty
    if [ -z "$GIT_FLOW_CMD" ]; then
        echo "[SKIPPING] GIT_FLOW_CMD is empty"
        return 1
    fi

    # check if GIT_FLOW_CMD is check or help or merge
    if [[ "$GIT_FLOW_CMD" != "check" && "$GIT_FLOW_CMD" != "help" && "$GIT_FLOW_CMD" != "merge" ]]; then
        echo "[SKIPPING] GIT_FLOW_CMD is not check or help or merge"
        return 1
    fi

    # post thunbs up reaction to the comment
    curl -X POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID/reactions --data '{"content": "+1"}' --silent --output /dev/null
}

check_if_author_is_allowed(){  
    # check if allowed authors is set
    if [ -z "$ALLOWED_AUTHORS" ]; then
        echo "No allowed authors set"
        exit 1
    fi
    # check if comment author is empty
    if [ -z "$COMMENT_AUTHOR" ]; then
        echo "Comment Author is empty"
        exit 1
    fi
    allowed=false
    # check if comment author is allowed
    for i in $(echo $ALLOWED_AUTHORS | tr ',' '\n')
    do
        if [ "$i" = "$COMMENT_AUTHOR" ]; then
            allowed=true
        fi
    done
    if [ "$allowed" = false ]; then
        return 1
    else
        return 0
    fi
}

detect_procees_from_branch_name() {
    # check if branch name is empty
    if [ -z "$BRANCH_NAME" ]; then
        echo "Branch Name is empty"
        return 1
    fi
    # check if branch name starts with feature prefix
    if [[ "$BRANCH_NAME" == "$FEATURE_BRANCH_PREFIX"* ]]; then
        export GIT_FLOW_PROCESS="feature"
    # check if branch name starts with hotfix prefix
    elif [[ "$BRANCH_NAME" == "$HOTFIX_BRANCH_PREFIX"* ]]; then
        export GIT_FLOW_PROCESS="hotfix"
    # check if branch name starts with bugfix prefix
    elif [[ "$BRANCH_NAME" == "$BUGFIX_BRANCH_PREFIX"* ]]; then
        export GIT_FLOW_PROCESS="bugfix"
    # check if branch name starts with release prefix
    elif [[ "$BRANCH_NAME" == "$RELEASE_BRANCH_PREFIX"* ]]; then
        export GIT_FLOW_PROCESS="release"
    else
        echo "Branch Name does not match any git flow process"
        return 1
    fi
}

HELP_MESSAGE="Usage: $TRIGGER_CMD [check|help|merge]\n\r\
check: check if the current branch is ready to be merged\n\r\
help: show this help message\n\r\
merge: merge the current branch, aka excute git flow ... finish command\n\r\
if the current branch is relase branch version tag input is required, e.g. $TRIGGER_CMD merge 1.0.0\n\r"

NOT_MERGEABLE_MESSAGE="This branch is not ready to be merged, please check the following:\n\r\
- The branch has no conflicts with the $DEVELOP_BRANCH branch\n\r\
- The branch has no conflicts with the $PRODUCTION_BRANCH branch\n\r\
- The PR is not in draft mode\n\r\
- Required checks are passing\n\r\
- Required approvals are given\n\r"

exec_help() {
   post_message_to_pr "$HELP_MESSAGE"
}

exec_check() {
    # check if PR MERGEABLE, CLEAN and not DRAFT
    if [[ $MERGEABLE != "MERGEABLE" || $IS_DRAFT = 'true' || $MERGE_STATE_STATUS != "CLEAN" ]]; then
        post_message_to_pr "$NOT_MERGEABLE_MESSAGE"
        return 1
    else
        post_message_to_pr "This branch is ready to be merged, please comment again $TRIGGER_CMD merge"
        return 0
    fi
}

pull_branches(){
    git config --global --add safe.directory "$GITHUB_WORKSPACE"
    git fetch origin
    # pull develop branch
    git checkout $DEVELOP_BRANCH
    git pull origin $DEVELOP_BRANCH
    # pull production branch
    git checkout $PRODUCTION_BRANCH
    git pull origin $PRODUCTION_BRANCH
}

exec_merge(){
    # check if MERGEABLE
    if [ "$MERGEABLE" = "false" ]; then
        post_message_to_pr "$NOT_MERGEABLE_MESSAGE"
        return 1
    else
        # checkout branch
        git checkout $BRANCH_NAME
        export GIT_MERGE_AUTOEDIT=no
        VERSION=$(echo "$BRANCH_NAME" | cut -d'/' -f2)
        if [ "$GIT_FLOW_PROCESS" = "feature" ]; then
            GIT_FLOW_EXEC="git flow feature finish \"$VERSION\" --keepremote"
        elif [ "$GIT_FLOW_PROCESS" = "hotfix" ]; then
            GIT_FLOW_EXEC="git flow hotfix finish -m \"$VERSION\" \"$VERSION\" --keepremote"
        elif [ "$GIT_FLOW_PROCESS" = "bugfix" ]; then
            GIT_FLOW_EXEC="git flow bugfix finish \"$VERSION\" --keepremote"
        elif [ "$GIT_FLOW_PROCESS" = "release" ]; then
            GIT_FLOW_EXEC="git flow release finish -m \"$VERSION\" \"$VERSION\" --keepremote"
        else
            echo "\xE2\x9D\x8C GIT_FLOW_PROCESS is not feature or hotfix or bugfix"
            return 1
        fi

        # execute git flow finish command and store output
        GIT_FLOW_OUTPUT=$(eval $GIT_FLOW_EXEC)
        if [ $? -eq 0 ]; then
            printf "\xE2\x9C\x94 Branch merged successfully\n\r"
        else
            printf "\xE2\x9D\x8C Branch merge failed"
            return 1
        fi
        # git push origin $DEVELOP_BRANCH --tags
        # git push origin $PRODUCTION_BRANCH --tags
        # git push origin :$BRANCH_NAME
        # close PR
        # curl -X PATCH -H "Accept: application/vnd.github.v3+json" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER --data '{"state": "closed"}' --silent --output /dev/null
        post_message_to_pr "Merged successfully, and deleted the branch\n\rResult:\n\r$GIT_FLOW_OUTPUT"
        return 0
    fi
}

exec_git_flow_process() {
    # exec GIT_FLOW_CMD check, help or merge
    if [ "$GIT_FLOW_CMD" = "check" ]; then
        exec_check
    elif [ "$GIT_FLOW_CMD" = "help" ]; then
        exec_help
    elif [ "$GIT_FLOW_CMD" = "merge" ]; then
        exec_merge
    fi
}

pull_branches
if check_if_author_is_allowed; then
    printf "\xE2\x9C\x94 Author is allowed\n\r"
else
    printf "\xE2\x9D\x8C Author is not allowed\n\r"
    exit 1
fi

if gitflow_init; then
    printf "\xE2\x9C\x94 Gitflow initialized\n\r"
else
    printf "\xE2\x9D\x8C Gitflow initialization failed\n\r"
    exit 1
fi

if process_issue_comment; then
    printf "\xE2\x9C\x94 Issue comment processed\n\r"
    if detect_procees_from_branch_name; then
        printf "\xE2\x9C\x94 Git flow process detected\n\r"
        exec_git_flow_process
    else
        printf "\xE2\x9D\x8C Git flow process detection failed\n\r"
        exit 1
    fi
fi

printf "\xE2\x9C\x94 Done"