import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import {
  FORMAT,
  PICK_DATE_AND_TIME,
  SET_BASED_ON_LAST_POST
} from "select-box-kit/components/future-date-input-selector";

import { PUBLISH_TO_CATEGORY_STATUS_TYPE } from 'discourse/controllers/edit-topic-timer';

export default Ember.Component.extend({
  selection: null,
  date: null,
  time: null,
  isCustom: Ember.computed.equal('selection', PICK_DATE_AND_TIME),
  isBasedOnLastPost: Ember.computed.equal('selection', SET_BASED_ON_LAST_POST),
  displayLabel: null,

  init() {
    this._super();

    const input = this.get('input');

    if (input) {
      if (this.get('basedOnLastPost')) {
        this.set('selection', SET_BASED_ON_LAST_POST);
      } else {
        this.set('selection', PICK_DATE_AND_TIME);
        const datetime = moment(input);
        this.set('date', datetime.toDate());
        this.set('time', datetime.format("HH:mm"));
        this._updateInput();
      }
    }
  },

  @observes("date", "time")
  _updateInput() {
    const date = moment(this.get('date')).format("YYYY-MM-DD");
    const time = (this.get('time') && ` ${this.get('time')}`) || '';
    this.set('input', moment(`${date}${time}`).format(FORMAT));
  },

  @observes("isBasedOnLastPost")
  _updateBasedOnLastPost() {
    this.set('basedOnLastPost', this.get('isBasedOnLastPost'));
  },

  @computed("input", "isBasedOnLastPost")
  duration(input, isBasedOnLastPost) {
    const now = moment();

    if (isBasedOnLastPost) {
      return parseFloat(input);
    } else {
      return moment(input) - now;
    }
  },

  @computed("input", "isBasedOnLastPost")
  executeAt(input, isBasedOnLastPost) {
    if (isBasedOnLastPost) {
      return moment().add(input, 'hours').format(FORMAT);
    } else {
      return input;
    }
  },

  didReceiveAttrs() {
    this.set('displayLabel', I18n.t(this.get('label') || 'topic.topic_status_update.when'));
  },

  @computed("statusType", "input", "isCustom", "date", "time", "willCloseImmediately", "categoryId")
  showTopicStatusInfo(statusType, input, isCustom, date, time, willCloseImmediately, categoryId) {
    if (!statusType || willCloseImmediately) return false;

    if (statusType === PUBLISH_TO_CATEGORY_STATUS_TYPE && Ember.isEmpty(categoryId)) {
      return false;
    }

    if (isCustom) {
      return date || time;
    } else {
      return input;
    }
  },

  @computed('isBasedOnLastPost', 'input', 'lastPostedAt')
  willCloseImmediately(isBasedOnLastPost, input, lastPostedAt) {
    if (isBasedOnLastPost && input) {
      let closeDate = moment(lastPostedAt);
      closeDate = closeDate.add(input, 'hours');
      return closeDate < moment();
    }
  },

  @computed('isBasedOnLastPost', 'lastPostedAt')
  willCloseI18n(isBasedOnLastPost, lastPostedAt) {
    if (isBasedOnLastPost) {
      const diff = Math.round((new Date() - new Date(lastPostedAt)) / (1000*60*60));
      return I18n.t('topic.auto_close_immediate', { count: diff });
    }
  },
});
