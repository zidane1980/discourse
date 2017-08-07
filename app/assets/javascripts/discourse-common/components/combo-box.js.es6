import { bufferedRender } from 'discourse-common/lib/buffered-render';
import { on, observes } from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse-common/lib/icon-library';

export default Ember.Component.extend(bufferedRender({
  tagName: 'select',
  attributeBindings: ['tabindex', 'disabled'],
  classNames: ['combobox'],
  valueAttribute: 'id',
  nameProperty: 'name',

  buildBuffer(buffer) {
    const nameProperty = this.get('nameProperty');
    const none = this.get('none');
    let noneValue = null;

    // Add none option if required
    if (typeof none === "string") {
      buffer.push('<option value="">' + I18n.t(none) + "</option>");
    } else if (typeof none === "object") {
      noneValue = Em.get(none, this.get('valueAttribute'));
      buffer.push(`<option value="${noneValue}">${Em.get(none, nameProperty)}</option>`);
    }

    let selected = this.get('value');
    if (!Em.isNone(selected)) { selected = selected.toString(); }

    let selectedFound = false;
    let firstVal = undefined;
    const content = this.get('content');

    if (content) {
      let first = true;
      content.forEach(o => {
        let val = o[this.get('valueAttribute')];
        if (typeof val === "undefined") { val = o; }
        if (!Em.isNone(val)) { val = val.toString(); }

        const selectedText = (val === selected) ? "selected" : "";
        const name = Handlebars.Utils.escapeExpression(Ember.get(o, nameProperty) || o);

        if (val === selected) {
          selectedFound = true;
        }
        if (first) {
          firstVal = val;
          first = false;
        }
        buffer.push(`<option ${selectedText} value="${val}">${name}</option>`);
      });
    }

    if (!selectedFound && !noneValue) {
      if (none) {
        this.set('value', null);
      } else {
        this.set('value', firstVal);
      }
    }

    Ember.run.scheduleOnce('afterRender', this, this._updateSelect2);
  },

  @observes('value')
  valueChanged() {
    const $combo = this.$(),
          val = this.get('value');

    if (val !== undefined && val !== null) {
      $combo.select2('val', val.toString());
    } else {
      $combo.select2('val', null);
    }
  },

  @observes('content.[]')
  _rerenderOnChange() {
    this.rerenderBuffer();
  },

  didInsertElement() {
    this._super();

    // Workaround for https://github.com/emberjs/ember.js/issues/9813
    // Can be removed when fixed. Without it, the wrong option is selected
    this.$('option').each((i, o) => o.selected = !!$(o).attr('selected'));

    // observer for item names changing (optional)
    if (this.get('nameChanges')) {
      this.addObserver('content.@each.' + this.get('nameProperty'), this.rerenderBuffer);
    }

    const $elem = this.$();
    const caps = this.capabilities;
    const minimumResultsForSearch = this.get('minimumResultsForSearch') || ((caps && caps.isIOS) ? -1 : 5);

    if (!this.get("selectionTemplate") && this.get("selectionIcon")) {
      this.selectionTemplate = (item) => {
        let name = Em.get(item, 'text');
        name = Handlebars.escapeExpression(name);
        return iconHTML(this.get('selectionIcon')) + name;
      };
    }

    const options = {
      minimumResultsForSearch,
      width: this.get('width') || 'resolve',
      allowClear: true
    };

    if (this.comboTemplate) {
      options.formatResult = this.comboTemplate.bind(this);
    }

    if (this.selectionTemplate) {
      options.formatSelection = this.selectionTemplate.bind(this);
    }

    $elem.select2(options);

    const castInteger = this.get('castInteger');
    $elem.on("change", e => {
      let val = $(e.target).val();
      if (val && val.length && castInteger) {
        val = parseInt(val, 10);
      }
      this.set('value', val);
    });

    Ember.run.scheduleOnce('afterRender', this, this._triggerChange);
  },

  _updateSelect2() {
    this.$().trigger('change.select2');
  },

  _triggerChange() {
    this.$().trigger('change');
  },

  @on('willDestroyElement')
  _destroyDropdown() {
    this.$().select2('destroy');
  }

}));
