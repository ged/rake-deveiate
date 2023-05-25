# Release History for rake-deveiate

---
## v0.23.0 [2023-05-25] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Update gem-signing cert, dependencies
- Fix breaking change in git gem


## v0.22.0 [2023-01-02] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Make Sixfish the default RDoc generator

Bugfixes:

- Fix diffing for the history file under Git


## v0.21.0 [2022-11-14] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Only include plain files in the manifest
- Allow declaration of alternative RDoc generator


## v0.20.0 [2022-09-19] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Allow default manifest to be modified

Bugfixes:

- Add missing homepage constant


## v0.19.2 [2021-07-15] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Defer gem path until version_from has a chance to be defined



## v0.19.1 [2021-05-08] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix version and version_from.


## v0.19.0 [2021-03-08] Michael Granger <ged@FaerieMUD.org>

Enhancements:

- Add support for SCP gem pushing.

Bugfixes:

- Push git repos with tags.


## v0.18.0 [2021-01-07] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add gem push key setting
- Add release branch check
- Fix a bunch of git functionality


## v0.17.4 [2021-01-02] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Ignore prerelease tags when checking history file.


## v0.17.3 [2021-01-01] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix maintainer task of extensions lib.


## v0.17.2 [2020-12-29] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix multi-directory extension directory support.


## v0.17.1 [2020-12-28] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Update hglib dependency


## v0.17.0 [2020-12-28] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Allow multi-level extension directory structure.


## v0.16.2 [2020-11-23] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Include another missing file.


## v0.16.1 [2020-11-23] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Include missing `git` tasklib.


## v0.16.0 [2020-11-23] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add support for projects managed with Git.


## v0.15.1 [2020-10-29] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Add the extension tasks file to the gem.


## v0.15.0 [2020-10-29] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Added support for extensions


## v0.14.1 [2020-10-01] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Support changes in latest tty-editor.


## v0.14.0 [2020-04-02] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Handle gem names like 'ruby-pf', fixup untracked gem deps files


## v0.13.0 [2020-03-09] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Allow file that version is read from to be overridden

Bugfixes:

- Bump the hglib dependency


## v0.12.1 [2020-03-04] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Stop truncating the description extracted from the README.


## v0.12.0 [2020-03-04] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add fixup tasks, example global rakefile


## v0.11.0 [2020-02-26] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add metadata extraction.
- Try to strip markup from the gemspec description and summary

Bugfixes:

- Fix a bug in history file task when there's already an entry for the current version.


## v0.10.0 [2020-02-12] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Find/include executables in the gemspec.


## v0.9.0 [2020-02-05] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Fix gem signing for projects with more than one cert.


## v0.8.0 [2020-01-22] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix a `clean` task that was breaking release builds

Improvements:

- Add `post_install_message` gemspec accessor


## v0.7.0 [2020-01-09] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add support for required_ruby_version.


## v0.6.0 [2019-12-24] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Update to the newest Rake.


## v0.5.0 [2019-11-13] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add a 'setup' task


## v0.4.2 [2019-10-30] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix allowed gem push setting
- Make README parsing a bit more forgiving, especially for RDoc
- Handle commit message whitespace consistently


## v0.4.1 [2019-10-17] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Make a gem from a new pkg/ directory every time.


## v0.4.0 [2019-10-16] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Offer to clear the current topic on release
- Add support for the `allowed_push_host` gem attribute

Bugfixes:

- Only try to sign if the gpg extension is loaded


## v0.3.0 [2019-10-14] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Add a `diff_manifest` task
- Run checkin tasks in an order that makes more sense
- Fix the sign/tag sequence in `release` to allow `sigcheck`ing the tag.


## v0.2.0 [2019-10-12] Michael Granger <ged@FaerieMUD.org>

Improvements:

- Enable integration tests when present
- Add APIdocs publishing, simplify commit log editing


## v0.1.1 [2019-10-12] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

- Fix a few typos.


## v0.1.0 [2019/10/02] Michael Granger <ged@FaerieMUD.org>

First release.
