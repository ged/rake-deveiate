# Release History for rake-deveiate

---

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
