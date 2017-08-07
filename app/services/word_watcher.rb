class WordWatcher

  def initialize(raw)
    @raw = raw
  end

  def self.words_for_action(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).limit(1000).pluck(:word)
  end

  def self.words_for_action_exists?(action)
    WatchedWord.where(action: WatchedWord.actions[action.to_sym]).exists?
  end

  def self.word_matcher_regexp(action)
    s = Discourse.cache.fetch(word_matcher_regexp_key(action), expires_in: 1.day) do
      words = words_for_action(action)
      words.empty? ? nil : '\b(' + words.map { |w| Regexp.escape(w).gsub("\\*", '\S*') }.join('|'.freeze) + ')\b'
    end

    s.present? ? Regexp.new(s, Regexp::IGNORECASE) : nil
  end

  def self.word_matcher_regexp_key(action)
    "watched-words-regexp:#{action}"
  end

  def self.clear_cache!
    WatchedWord.actions.sum do |a, i|
      Discourse.cache.delete word_matcher_regexp_key(a)
    end
  end

  def requires_approval?
    word_matches_for_action?(:require_approval)
  end

  def should_flag?
    word_matches_for_action?(:flag)
  end

  def should_block?
    word_matches_for_action?(:block)
  end

  def word_matches_for_action?(action)
    r = self.class.word_matcher_regexp(action)
    r ? r.match(@raw) : false
  end

end
