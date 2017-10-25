// A service that can act as a bridge between the front end Discourse application
// and the admin application. Use this if you need front end code to access admin
// modules. Inject it optionally, and if it exists go to town!

import AdminUser from 'admin/models/admin-user';
import { iconHTML } from 'discourse-common/lib/icon-library';
import { ajax } from 'discourse/lib/ajax';
import showModal from 'discourse/lib/show-modal';

export default Ember.Service.extend({

  checkSpammer(userId) {
    return AdminUser.find(userId).then(au => this.spammerDetails(au));
  },

  spammerDetails(adminUser) {
    return {
      deleteUser: () => this._deleteSpammer(adminUser),
      canDelete: adminUser.get('can_be_deleted') && adminUser.get('can_delete_all_posts')
    };
  },

  showSuspendModal(user, opts) {
    opts = opts || {};

    let controller = showModal('admin-suspend-user', {
      admin: true,
      modalClass: 'suspend-user-modal'
    });
    if (opts.post) {
      controller.set('post', opts.post);
    }

    let promise = user.adminUserView ?
      Ember.RSVP.resolve(user) :
      AdminUser.find(user.get('id'));

    promise.then(loadedUser => {
      controller.setProperties({
        user: loadedUser,
        loadingUser: false,
        successCallback: opts.successCallback
      });
    });
  },

  _deleteSpammer(adminUser) {
    return adminUser.checkEmail().then(() => {

      let message = I18n.messageFormat('flagging.delete_confirm_MF', {
        "POSTS": adminUser.get('post_count'),
        "TOPICS": adminUser.get('topic_count'),
        email: adminUser.get('email') || I18n.t("flagging.hidden_email_address"),
        ip_address: adminUser.get('ip_address') || I18n.t("flagging.ip_address_missing")
      });

      let userId = adminUser.get('id');

      return new Ember.RSVP.Promise((resolve, reject) => {
        const buttons = [
          {
            label: I18n.t("composer.cancel"),
            class: "d-modal-cancel",
            link:  true
          },
          {
            label: `${iconHTML('exclamation-triangle')} ` + I18n.t("flagging.yes_delete_spammer"),
            class: "btn btn-danger confirm-delete",
            callback() {
              return ajax(`/admin/users/${userId}.json`, {
                type: 'DELETE',
                data: {
                  delete_posts: true,
                  block_email: true,
                  block_urls: true,
                  block_ip: true,
                  delete_as_spammer: true,
                  context: window.location.pathname
                }
              }).then(result => {
                if (result.deleted) {
                  resolve();
                } else {
                  throw 'failed to delete';
                }
              }).catch(() => {
                bootbox.alert(I18n.t("admin.user.delete_failed"));
                reject();
              });
            }
          }
        ];

        bootbox.dialog(message, buttons, {classes: "flagging-delete-spammer"});
      });

    });
  }

});
