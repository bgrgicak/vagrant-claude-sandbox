# Publishing Guide

This guide describes how to publish new versions of the vagrant-claude-sandbox plugin to RubyGems.

## Prerequisites

1. RubyGems account at [rubygems.org](https://rubygems.org)
2. Configure RubyGems credentials:
   ```bash
   gem signin
   ```

## Pre-Publish Checklist

1. **Update Version**
   - Edit [lib/vagrant-claude-sandbox/version.rb](lib/vagrant-claude-sandbox/version.rb)
   - Follow [semantic versioning](https://semver.org/):
     - MAJOR: Breaking changes
     - MINOR: New features (backward compatible)
     - PATCH: Bug fixes

2. **Update CHANGELOG.md**
   - Add release date and version
   - Document all changes, fixes, and new features
   - Follow [Keep a Changelog](https://keepachangelog.com/) format

3. **Test Locally**
   ```bash
   # Build the gem
   gem build vagrant-claude-sandbox.gemspec

   # Install locally to test
   vagrant plugin install ./vagrant-claude-sandbox-*.gem

   # Test in a fresh directory
   vagrant up
   vagrant ssh
   # Verify Claude works inside VM
   ```

4. **Verify Files**
   - Ensure README.md is up to date
   - Check LICENSE file exists
   - Verify all required files are included in gemspec

## Publishing Steps

1. **Build the Gem**
   ```bash
   gem build vagrant-claude-sandbox.gemspec
   ```

   This creates `vagrant-claude-sandbox-<version>.gem`

2. **Publish to RubyGems**
   ```bash
   gem push vagrant-claude-sandbox-<version>.gem
   ```

3. **Verify Publication**
   - Check [rubygems.org/gems/vagrant-claude-sandbox](https://rubygems.org/gems/vagrant-claude-sandbox)
   - Install from RubyGems to verify:
     ```bash
     vagrant plugin install vagrant-claude-sandbox
     ```

4. **Create Git Tag**
   ```bash
   git tag -a v<version> -m "Release v<version>"
   git push origin v<version>
   ```

5. **Create GitHub Release**
   - Go to [Releases](https://github.com/bgrgicak/vagrant-claude-sandbox/releases)
   - Click "Draft a new release"
   - Select the tag you just created
   - Copy changelog entries for this version
   - Publish release

## Post-Publish

1. Announce the release (optional):
   - Twitter/X
   - Reddit (r/vagrant)
   - Community forums

2. Monitor for issues:
   - Watch GitHub issues
   - Check RubyGems download stats

## Troubleshooting

### Authentication Issues
If `gem push` fails with authentication errors:
```bash
gem signin
# Enter your RubyGems credentials
```

### Version Already Exists
RubyGems does not allow republishing the same version. Increment the version number and rebuild.

### Missing Files
Verify the gemspec includes all necessary files:
```bash
gem spec vagrant-claude-sandbox-<version>.gem
```

## Unpublishing (Emergency Only)

If you need to remove a version (within 24 hours of publishing):
```bash
gem yank vagrant-claude-sandbox -v <version>
```

Note: This should only be done for critical security issues or broken releases.
