import createStore from 'helpers/create-store';

QUnit.module("lib:category-link");

import parseHTML from 'helpers/parse-html';
import { categoryBadgeHTML } from "discourse/helpers/category-link";

QUnit.test("categoryBadge without a category", assert => {
  assert.blank(categoryBadgeHTML(), "it returns no HTML");
});

QUnit.test("Regular categoryBadge", assert => {
  const store = createStore();
  const category = store.createRecord('category', {
          name: 'hello',
          id: 123,
          description_text: 'cool description',
          color: 'ff0',
          text_color: 'f00'
        });
  const tag = parseHTML(categoryBadgeHTML(category))[0];

  assert.equal(tag.name, 'a', 'it creates a `a` wrapper tag');
  assert.equal(tag.attributes['class'].trim(), 'badge-wrapper', 'it has the correct class');

  const label = tag.children[1];
  assert.equal(label.attributes.title, 'cool description', 'it has the correct title');

  assert.equal(label.children[0].data, 'hello', 'it has the category name');
});

QUnit.test("undefined color", assert => {
  const store = createStore();
  const noColor = store.createRecord('category', { name: 'hello', id: 123 });
  const tag = parseHTML(categoryBadgeHTML(noColor))[0];

  assert.blank(tag.attributes.style, "it has no color style because there are no colors");
});

QUnit.test("allowUncategorized", assert => {
  const store = createStore();
  const uncategorized = store.createRecord('category', {name: 'uncategorized', id: 345});
  sandbox.stub(Discourse.Site, 'currentProp').withArgs('uncategorized_category_id').returns(345);

  assert.blank(categoryBadgeHTML(uncategorized), "it doesn't return HTML for uncategorized by default");
  assert.present(categoryBadgeHTML(uncategorized, {allowUncategorized: true}), "it returns HTML");
});