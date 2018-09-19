#!/bin/bash
# Given a search string, find all the orgs for all users that match that string

# Get the username string we're interested in
if [[ -z $1 ]]; then
  echo "Please specify a serach string to search for users and get their orgs"
  exit 1
fi
user=$1

# Check to see if we're logged in and targeted
if ! cf target 2>&1 > /dev/null; then
  echo "cf target failed"
  exit 1
fi

# Get # pages of users
user_pages=$(cf curl v2/users?results-per-page=100 | jq -r '.total_pages')

# Find the number of 'pages' of users, 100 users per page
# Get the user urls for all matched users
declare -a user_urls
user_page=1
i=0
echo "Found $user_pages pages full of happy little users"
echo "Searching all the happy little users can take some time, please be patient"
while (( $user_page <= $user_pages )); do
  printf "\nWorking on page $user_page of $user_pages\n"
  for user_url in $(cf curl v2/users?results-per-page=100\&page=$user_page | jq -r '.resources[].metadata.url'); do
    # cf curl running in gitbash on windows does not work with a forward slash
    # e.g. /v2/users/333bb853-753f-4821-9ccb-9c473f34b934/organizations.
    # remove forward slash with {var:1}
    user_url="${user_url:1}"

    if cf curl "$user_url" | jq -e --arg user "$user" 'select (.entity.username | contains($user))'; then
      user_urls[$i]=$user_url
      (( i++ ))
    fi

    printf "."
  done
  (( user_page++ ))
done

## Print the index and value of each element in the user_urls array
## Useful for debugging
## for j in "${!user_urls[@]}"; do
##  printf "%s\t%s\n" "$j" "${user_urls[$j]}"
## done

# Test if user_url is still not set after searching all the pages
# If user_urls is empty, that means that the given username string was not found
if (( ${#user_urls[@]} == 0 )); then
  printf "\nNo users matching the string '$user' can be found\n\n"
  exit 1
else
  printf "\nFound ${#user_urls[@]} users matching '$user'\n"
fi

# Get the orgs for the matched users
# Itereate through all the user_urls and get the username and orgs for each user
i=0
while (( $i < ${#user_urls[@]} )); do
  user_orgs=$(cf curl $(cf curl ${user_urls[i]} | jq -r '.entity.organizations_url') | jq -r '.resources[].entity.name')
  user_name=$(cf curl ${user_urls[i]}? | jq -r '.entity.username')
  printf "\nThe user '$user_name' is a member of the following orgs:\n"
  printf "$user_orgs\n"
  (( i++ ))
done

