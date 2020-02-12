# Release History for rake-deveiate

---

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
