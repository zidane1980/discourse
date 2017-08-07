class GroupShowSerializer < BasicGroupSerializer
  attributes :is_group_user, :is_group_owner, :mentionable

  def include_is_group_user?
    authenticated?
  end

  def is_group_user
    !!fetch_group_user
  end

  def include_is_group_owner?
    authenticated?
  end

  def is_group_owner
    scope.is_admin? || fetch_group_user&.owner
  end

  def include_mentionable?
    authenticated?
  end

  def mentionable
    Group.mentionable(scope.user).exists?(id: object.id)
  end

  private

  def authenticated?
    scope.authenticated?
  end

  def fetch_group_user
    @group_user ||= object.group_users.find_by(user: scope.user)
  end
end
