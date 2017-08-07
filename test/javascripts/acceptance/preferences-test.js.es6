import { acceptance } from "helpers/qunit-helpers";
acceptance("User Preferences", { loggedIn: true });

QUnit.test("update some fields", assert => {
  visit("/u/eviltrout/preferences");

  andThen(() => {
    assert.ok($('body.user-preferences-page').length, "has the body class");
    assert.equal(currentURL(), '/u/eviltrout/preferences/account', "defaults to account tab");
    assert.ok(exists('.user-preferences'), 'it shows the preferences');
  });

  const savePreferences = () => {
    click('.save-user');
    assert.ok(!exists('.saved-user'), "it hasn't been saved yet");
    andThen(() => {
      assert.ok(exists('.saved-user'), 'it displays the saved message');
    });
  };

  fillIn(".pref-name input[type=text]", "Jon Snow");
  savePreferences();

  click(".preferences-nav .nav-profile a");
  fillIn("#edit-location", "Westeros");
  savePreferences();

  click(".preferences-nav .nav-emails a");
  click(".pref-activity-summary input[type=checkbox]");
  savePreferences();

  click(".preferences-nav .nav-notifications a");
  selectDropdown('.control-group.notifications select.combobox', 1440);
  savePreferences();

  click(".preferences-nav .nav-categories a");
  fillIn('.category-controls .category-selector', 'faq');
  savePreferences();

  assert.ok(!exists('.preferences-nav .nav-tags a'), "tags tab isn't there when tags are disabled");

  // Error: Unhandled request in test environment: /themes/assets/10d71596-7e4e-4dc0-b368-faa3b6f1ce6d?_=1493833562388 (GET)
  // click(".preferences-nav .nav-interface a");
  // click('.control-group.other input[type=checkbox]:first');
  // savePreferences();

  assert.ok(!exists('.preferences-nav .nav-apps a'), "apps tab isn't there when you have no authorized apps");
});

QUnit.test("username", assert => {
  visit("/u/eviltrout/preferences/username");
  andThen(() => {
    assert.ok(exists("#change_username"), "it has the input element");
  });
});

QUnit.test("about me", assert => {
  visit("/u/eviltrout/preferences/about-me");
  andThen(() => {
    assert.ok(exists(".raw-bio"), "it has the input element");
  });
});

QUnit.test("email", assert => {
  visit("/u/eviltrout/preferences/email");
  andThen(() => {
    assert.ok(exists("#change-email"), "it has the input element");
  });

  fillIn("#change-email", 'invalidemail');

  andThen(() => {
    assert.equal(find('.tip.bad').text().trim(), I18n.t('user.email.invalid'), 'it should display invalid email tip');
  });
});