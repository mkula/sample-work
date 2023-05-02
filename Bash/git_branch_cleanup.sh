#!/bin/sh
## This script iterates over a list of the local branches in a given repository
## Each local and its corresponding remote branch can then be removed


# get the location of a git repository
# ensure we got a valid reponse
user=$(whoami)
until [ "X$git_path" != "X" ] && cd $git_path
do
  printf "\nType the full path of a git repository [/data/home/${user}/git/client/]: "
  read git_path

  if [ "X$git_path" == "X" ]
  then
    git_path="/data/home/${user}/git/client/"
  fi
done


remote="remotes/origin/"
local="refs/heads/"
branch=""

# iterate over the local branch list
for branch in $(git for-each-ref --shell --format='%(refname)' $local | sed "s/^'refs\/heads\///g" | sed "s/'$//g")
do
  # skip the local master branch
  if [ "$branch" == "master" ]
  then
    continue
  fi

  input=""
  ########################### local branch ##################################
  # ensure we got a valid response
  until [ "$input" == "Y" ] || [ "$input" == "y" ] || [ "$input" == "N" ] || [ "$input" == "n" ] || [ "$input" == "Q" ] || [ "$input" == "q" ]
  do
    printf "\nLocal branch '$branch'. Remove it [Y|N|Q]?: "
    read input
  done

  # quit the program?
  if [ "$input" = "Q" ] || [ "$input" = "q" ]
  then
    echo
    exit 0
  fi

  # force remove the local branch
  if [ "$input" = "Y" ] || [ "$input" = "y" ]
  then
    git branch -D $branch
  fi

  input=""
  ########################### remote branch ##################################
  if git branch -a | grep "$remote$branch" > /dev/null
  then
    # ensure we got a valid response
    until [ "$input" == "Y" ] || [ "$input" == "y" ] || [ "$input" == "N" ] || [ "$input" == "n" ] || [ "$input" == "Q" ] || [ "$input" == "q" ]
    do
      printf "\nRemote branch '$remote$branch'. Remove it [Y|N|Q]?: "
      read input
    done

    # quit the program?
    if [ "$input" = "Q" ] || [ "$input" = "q" ]
    then
      echo
      exit 0
    fi

    # remove the remote branch
    if [ "$input" = "Y" ] || [ "$input" = "y" ]
    then
      git push origin :$branch
    fi
  fi
done

if [ "$branch" != "" ]
then
  echo
  echo "......................................................................................................"
  echo "      End of the list of the local branches in the '$git_path' repository."
  echo "......................................................................................................"
fi

echo
exit 0
