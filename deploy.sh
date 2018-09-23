# Partly taken from https://medium.com/@nielsenramon/automated-deployment-of-jekyll-projects-to-github-pages-using-kickster-and-circle-ci-6ccc0b6cb872#.qxsy1xf1m
# Partly taken from https://github.com/fastlane/docs

# Exit if any subcommand fails.
set -e

echo "Starting deploy to https://langefeld.online"

# Build the docs page locally
export JEKYLL_ENV="production"
bundle exec jekyll build

# Bots need names too
git config --global user.email "jekyllbot@langefeld.online"
git config --global user.name "Jekyll-Bot"

# Delete old directories (if any)
rm -rf "/tmp/langefeld.online"
# Copy the generated website to the temporary directory
cp -R "_site/" "/tmp/langefeld.online"

# Check out gh-pages and clear all files
git reset --hard HEAD # we don't want the `git checkout` to cause issues (e.g. https://circleci.com/gh/fastlane/docs/730)
git checkout -b gh-pages
git remote add upstream "https://$GH_TOKEN@github.com/jonnylangefeld/langefeld.online.git"
git pull
rm -rf *
# Copy the finished HTML pages to the current directory
cp -R /tmp/langefeld.online/* .

# We need a CNAME file for GitHub
echo "langefeld.online" > "CNAME"

# Commit all the changes and push it to the remote
git add -A
git commit -m "Deployed with $(jekyll -v)"
git push upstream gh-pages --force # force needed, as travis somehow can't re-use branches

# Post a Slack message
git checkout master

echo "Deployed successfully, check out https://langefeld.online"
echo "If you're running this on your local machine, please make sure to reset your git user credentials (username and email) to not be the bot"

exit 0
