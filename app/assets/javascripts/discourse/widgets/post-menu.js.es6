import { applyDecorators, createWidget } from 'discourse/widgets/widget';
import { avatarAtts } from 'discourse/widgets/actions-summary';
import { h } from 'virtual-dom';

const LIKE_ACTION = 2;

function animateHeart($elem, start, end, complete) {
  if (Ember.testing) { return Ember.run(this, complete); }

  $elem.stop()
       .css('textIndent', start)
       .animate({ textIndent: end }, {
          complete,
          step(now) {
            $(this).css('transform','scale('+now+')');
          },
          duration: 150
        }, 'linear');
}

const _builders = {};
const _extraButtons = {};

export function addButton(name, builder) {
  _extraButtons[name] = builder;
}

function registerButton(name, builder) {
  _builders[name] = builder;
}

export function buildButton(name, widget) {
  let { attrs, state, siteSettings } = widget;
  let builder = _builders[name];
  if (builder) {
    let button = builder(attrs, state, siteSettings);
    if (button && !button.id) {
      button.id = name;
    }
    return button;
  }
}

registerButton('like', attrs => {
  if (!attrs.showLike) { return; }
  const className = attrs.liked ? 'toggle-like has-like fade-out' : 'toggle-like like';

  const button = {
    action: 'like',
    icon: attrs.liked ? 'd-liked' : 'd-unliked',
    className
  };


  if (attrs.canToggleLike) {
    button.title = attrs.liked ? 'post.controls.undo_like' : 'post.controls.like';
  } else if (attrs.liked) {
    button.title = 'post.controls.has_liked';
    button.disabled = true;
  }
  return button;
});

registerButton('like-count', attrs => {
  const count = attrs.likeCount;

  if (count > 0) {
    const title = attrs.liked
      ? count === 1 ? 'post.has_likes_title_only_you' : 'post.has_likes_title_you'
      : 'post.has_likes_title';

    return { action: 'toggleWhoLiked',
      title,
      className: 'like-count highlight-action',
      contents: I18n.t("post.has_likes", { count }),
      titleOptions: {count: attrs.liked ? (count-1) : count }
    };
  }
});

registerButton('flag', attrs => {
  if (attrs.canFlag) {
    return { action: 'showFlags',
             title: 'post.controls.flag',
             icon: 'flag',
             className: 'create-flag' };
  }
});

registerButton('edit', attrs => {
  if (attrs.canEdit) {
    return {
      action: 'editPost',
      className: 'edit',
      title: 'post.controls.edit',
      icon: 'pencil',
      alwaysShowYours: true
    };
  }
});

registerButton('reply-small', attrs => {
  if (!attrs.canCreatePost) { return; }

  const args = {
    action: 'replyToPost',
    title: 'post.controls.reply',
    icon: 'reply',
    className: 'reply',
  };

  return args;
});

registerButton('wiki-edit', attrs => {
  if (attrs.canEdit) {
    const args = {
      action: 'editPost',
      className: 'edit create',
      title: 'post.controls.edit',
      icon: 'pencil-square-o',
      alwaysShowYours: true
    };
    if (!attrs.mobileView) {
      args.label = 'post.controls.edit_action';
    }
    return args;
  }
});

registerButton('replies', (attrs, state, siteSettings) => {
  const replyCount = attrs.replyCount;

  if (!replyCount) { return; }

  // Omit replies if the setting `suppress_reply_directly_below` is enabled
  if (replyCount === 1 &&
      attrs.replyDirectlyBelow &&
      siteSettings.suppress_reply_directly_below) {
    return;
  }

  return {
    action: 'toggleRepliesBelow',
    className: 'show-replies',
    icon: state.repliesShown ? 'chevron-up' : 'chevron-down',
    titleOptions: { count: replyCount },
    title: 'post.has_replies',
    labelOptions: { count: replyCount },
    label: 'post.has_replies',
    iconRight: true
  };
});


registerButton('share', attrs => {
  return {
    action: 'share',
    className: 'share',
    title: 'post.controls.share',
    icon: 'link',
    data: {
      'share-url': attrs.shareUrl,
      'post-number': attrs.post_number
    }
  };
});

registerButton('reply', attrs => {
  const args = {
    action: 'replyToPost',
    title: 'post.controls.reply',
    icon: 'reply',
    className: 'reply create fade-out'
  };

  if (!attrs.canCreatePost) { return; }

  if (!attrs.mobileView) {
    args.label = 'topic.reply.title';
  }

  return args;
});

registerButton('bookmark', attrs => {
  if (!attrs.canBookmark) { return; }

  let className = 'bookmark';

  if (attrs.bookmarked) {
    className += ' bookmarked';
  }

  return {
    id: attrs.bookmarked ? 'bookmark' : 'unbookmark',
    action: 'toggleBookmark',
    title: attrs.bookmarked ? "bookmarks.created" : "bookmarks.not_bookmarked",
    className,
    icon: 'bookmark'
  };
});

registerButton('admin', attrs => {
  if (!attrs.canManage && !attrs.canWiki) { return; }
  return { action: 'openAdminMenu',
           title: 'post.controls.admin',
           className: 'show-post-admin-menu',
           icon: 'wrench' };
});

registerButton('delete', attrs => {
  if (attrs.canRecoverTopic) {
    return { id: 'recover_topic', action: 'recoverPost', title: 'topic.actions.recover', icon: 'undo', className: 'recover' };
  } else if (attrs.canDeleteTopic) {
    return { id: 'delete_topic', action: 'deletePost', title: 'topic.actions.delete', icon: 'trash-o', className: 'delete' };
  } else if (attrs.canRecover) {
    return { id: 'recover', action: 'recoverPost', title: 'post.controls.undelete', icon: 'undo', className: 'recover' };
  } else if (attrs.canDelete) {
    return { id: 'delete', action: 'deletePost', title: 'post.controls.delete', icon: 'trash-o', className: 'delete' };
  }
});

function replaceButton(buttons, find, replace) {
  const idx = buttons.indexOf(find);
  if (idx !== -1) {
    buttons[idx] = replace;
  }
}

export default createWidget('post-menu', {
  tagName: 'section.post-menu-area.clearfix',

  settings: {
    collapseButtons: true,
    buttonType: 'flat-button'
  },

  defaultState() {
    return { collapsed: true, likedUsers: [], adminVisible: false };
  },

  buildKey: attrs => `post-menu-${attrs.id}`,

  attachButton(name) {
    let buttonAtts = buildButton(name, this);
    if (buttonAtts) {
      return this.attach(this.settings.buttonType, buttonAtts);
    }
  },

  menuItems() {
    let result = this.siteSettings.post_menu.split('|');
    return result;
  },

  html(attrs, state) {
    const { siteSettings } = this;

    const hiddenSetting = (siteSettings.post_menu_hidden_items || '');
    const hiddenButtons = hiddenSetting.split('|').filter(s => {
      return !attrs.bookmarked || s !== 'bookmark';
    });

    const allButtons = [];
    let visibleButtons = [];

    const orderedButtons = this.menuItems();

    // If the post is a wiki, make Edit more prominent
    if (attrs.wiki) {
      replaceButton(orderedButtons, 'edit', 'reply-small');
      replaceButton(orderedButtons, 'reply', 'wiki-edit');
    }

    orderedButtons.forEach(i => {
      const button = this.attachButton(i, attrs);
      if (button) {
        allButtons.push(button);

        if ((attrs.yours && button.attrs.alwaysShowYours) || (hiddenButtons.indexOf(i) === -1)) {
          visibleButtons.push(button);
        }
      }
    });

    if (!this.settings.collapseButtons) {
      visibleButtons = allButtons;
    }

    // Only show ellipsis if there is more than one button hidden
    // if there are no more buttons, we are not collapsed
    if (!state.collapsed || (allButtons.length <= visibleButtons.length + 1)) {
      visibleButtons = allButtons;
      if (state.collapsed) { state.collapsed = false; }
    } else {
      const showMore = this.attach('flat-button', {
        action: 'showMoreActions',
        title: 'show_more',
        className: 'show-more-actions',
        icon: 'ellipsis-h' });
      visibleButtons.splice(visibleButtons.length - 1, 0, showMore);
    }

    Object.keys(_extraButtons).forEach(k => {
      const builder = _extraButtons[k];
      if (builder) {
        const buttonAtts = builder(attrs, this.state, this.siteSettings);
        if (buttonAtts) {
          const { position, beforeButton } = buttonAtts;
          delete buttonAtts.position;

          let button = this.attach(this.settings.buttonType, buttonAtts);

          if (beforeButton) {
            button = h('span', [beforeButton(h), button]);
          }

          if (button) {
            switch(position) {
              case 'first':
                visibleButtons.unshift(button);
                break;
              case 'second':
                visibleButtons.splice(1, 0, button);
                break;
              case 'second-last-hidden':
                if (!state.collapsed) {
                  visibleButtons.splice(visibleButtons.length-2, 0, button);
                }
                break;
              default:
                visibleButtons.push(button);
                break;
            }
          }
        }
      }
    });

    const postControls = [];

    const repliesButton = this.attachButton('replies', attrs);
    if (repliesButton) {
      postControls.push(repliesButton);
    }

    let extraControls = applyDecorators(this, 'extra-controls', attrs, state);
    postControls.push(h('div.actions', visibleButtons.concat(extraControls)));
    if (state.adminVisible) {
      postControls.push(this.attach('post-admin-menu', attrs));
    }

    const contents = [ h('nav.post-controls.clearfix', postControls) ];
    if (state.likedUsers.length) {
      contents.push(this.attach('small-user-list', {
        users: state.likedUsers,
        addSelf: attrs.liked,
        listClassName: 'who-liked',
        description: 'post.actions.people.like'
      }));
    }

    return contents;
  },

  openAdminMenu() {
    this.state.adminVisible = true;
  },

  closeAdminMenu() {
    this.state.adminVisible = false;
  },

  showMoreActions() {
    this.state.collapsed = false;
  },

  like() {
    if (!this.currentUser) {
      return this.sendWidgetAction('showLogin');
    }
    const attrs = this.attrs;
    if (attrs.liked) {
      return this.sendWidgetAction('toggleLike');
    }

    const $heart = $(`[data-post-id=${attrs.id}] .toggle-like .d-icon`);
    $heart.closest('button').addClass('has-like');

    if (!Ember.testing) {
      const scale = [1.0, 1.5];
      return new Ember.RSVP.Promise(resolve => {
        animateHeart($heart, scale[0], scale[1], () => {
          animateHeart($heart, scale[1], scale[0], () => {
            this.sendWidgetAction('toggleLike').then(() => resolve());
          });
        });
      });
    } else {
      this.sendWidgetAction('toggleLike');
    }
  },

  refreshLikes() {
    if (this.state.likedUsers.length) {
      return this.getWhoLiked();
    }
  },

  getWhoLiked() {
    const { attrs, state } = this;

    return this.store.find('post-action-user', { id: attrs.id, post_action_type_id: LIKE_ACTION }).then(users => {
      state.likedUsers = users.map(avatarAtts);
    });
  },

  toggleWhoLiked() {
    const state = this.state;
    if (state.likedUsers.length) {
      state.likedUsers = [];
    } else {
      return this.getWhoLiked();
    }
  },
});
