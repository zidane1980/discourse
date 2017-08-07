import MountWidget from 'discourse/components/mount-widget';
import { observes } from 'ember-addons/ember-computed-decorators';

export default MountWidget.extend({
  classNames: ['topic-notifications-container'],
  widget: 'topic-notifications-button',

  buildArgs() {
    return { topic: this.get('topic'), appendReason: true, showFullTitle: true };
  },

  @observes('topic.details.notification_level')
  _queueRerender() {
    this.queueRerender();
  },

  didInsertElement() {
    this._super();
    this.dispatch('topic-notifications-button:changed', 'topic-notifications-button');
  }
});
