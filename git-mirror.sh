#!/bin/bash

set -e
set -x

# name src dst
REPOS=(
    "WebSwarm   git@git.sr.ht:~jean-max/WebSwarm   git@github.com:JeanMax/WebSwarm"
    "swarm      git@git.sr.ht:~jean-max/swarm      git@github.com:JeanMax/swarm"
    "SpaceTripX git@git.sr.ht:~jean-max/SpaceTripX git@github.com:JeanMax/SpaceTripX"
    "git-mirror git@git.sr.ht:~jean-max/git-mirror git@github.com:JeanMax/git-mirror""
)

REPOS_DIR=$HOME/mirrors

gpla() {
    remote="$1"
    remote_show="$(git remote show "$remote")"

    branches=$(echo "$remote_show" | grep 'out of date' | cut -d' ' -f5)

    local_branches=$(echo "$remote_show" \
                         | grep -B 1000 'Local branches' \
                         | tail -n +6 \
                         | head -n -1 \
                         | cut -d' ' -f5)
    push_branches=$(echo "$remote_show" \
                        | grep -A 1000 'Local refs' \
                        | tail -n +2 \
                        | cut -d' ' -f5)
    diff=$(diff <(echo "$local_branches") <(echo "$push_branches"))
    if test "$diff"; then
        diff_branches=$(echo "$diff" | grep -E '^<' | cut -d' ' -f2)
        branches=$(echo "$diff_branches
$branches" | sort | uniq)
    fi

    if test "$branches"; then
		current_branch=$(git branch | grep '*' | cut -d' ' -f2)

		git fetch --all --prune
        echo
        for branch in $(echo $branches); do
            echo "[$branch] "
            git checkout "$branch"
			git merge --ff-only "$remote/$branch"
            echo
        done

        git checkout "$current_branch"
    fi
}

gpa() {
    origin_remote="$1"
    mirror_remote="$2"

    current_branch=$(git branch -a \
                         | grep HEAD \
                         | sed "s|.*-> $origin_remote/||")
    branches=$(git branch -a \
                   | grep "remotes/$origin_remote/" \
                   | grep -v HEAD \
                   | grep -v "$current_branch" \
                   | sed "s|.*remotes/$origin_remote/||")

    for b in $branches; do
        git checkout "$b" #--track "$origin_remote"
    done
    git checkout "$current_branch"

    git push "$mirror_remote" --all
    git push "$mirror_remote" --tags
}


mkdir -pv $REPOS_DIR
cd $REPOS_DIR

for r in "${REPOS[@]}"; do
    IFS=" " read -r name src dst <<< $r

    test -d $name || (
        git clone $src $name
        cd $name
        git remote add mirror $dst
    )

    (
        cd $name
        gpla origin
        gpa origin mirror
    )
done
