# Claude Code Instructions for Harbinger

## Release Protocol for Ruby Gems

This project is a Ruby gem. Follow this protocol strictly for every release:

### Pre-Release Checklist

1. **Update version number** in `lib/harbinger/version.rb`
   - Follow semantic versioning (MAJOR.MINOR.PATCH)

2. **Update CHANGELOG.md**
   - Add new version section with date: `## [X.Y.Z] - YYYY-MM-DD`
   - Categorize changes under: Added, Changed, Fixed, Removed, Technical
   - Review recent commits since last tag to ensure nothing is missed
   - Keep format consistent with existing entries

3. **Update README.md**
   - Document any new features, commands, or options
   - Update examples if behavior has changed
   - Update version references if needed

4. **Update docs/index.html** (if exists)
   - Document new features with examples
   - Keep in sync with README when applicable

5. **Update Homebrew formula** (if this gem has a Homebrew tap)
   - Update version number in the formula
   - Update SHA256 after publishing gem
   - Test installation: `brew install --build-from-source <formula>`
   - Submit PR to homebrew tap repository

### Release Steps

1. **Commit documentation changes**
   ```bash
   git add CHANGELOG.md README.md lib/harbinger/version.rb
   git commit -m "bump version to X.Y.Z"
   ```

2. **Create and push git tag**
   ```bash
   git tag vX.Y.Z
   git push origin main --tags
   ```

3. **Build and publish gem**
   ```bash
   gem build stackharbinger.gemspec
   gem push stackharbinger-X.Y.Z.gem
   ```

4. **If Homebrew formula exists**
   - Calculate new SHA256: `shasum -a 256 stackharbinger-X.Y.Z.gem`
   - Update formula with new version and SHA256
   - Test and submit PR to tap repository

## Important Notes

- This is a **gem project** - the release protocol above is mandatory
- Always verify all three files (CHANGELOG, README, docs/index) are updated before tagging
