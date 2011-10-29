require "cinch/cache_manager"

module Cinch
  class UserManager < CacheManager
    # Finds or creates a user.
    # @overload find_ensured(nick)
    #   Finds or creates a user based on his nick.
    #
    #   @param [String] nick The user's nickname
    #   @return [User]
    # @overload find_ensured(user, nick, host)
    #   Finds or creates a user based on his nick but already
    #   setting user and host.
    #
    #   @param [String] user The username
    #   @param [String] nick The nickname
    #   @param [String] host The user's hostname
    #   @return [User]
    # @return [User]
    # @see Bot#User
    def find_ensured(*args)
      case args.size
      when 1
        nick = args.first
        bargs = [nick]
      when 3
        nick = args[1]
        bargs = args
      else
        raise ArgumentError
      end
      downcased_nick = nick.irc_downcase(@bot.irc.isupport["CASEMAPPING"])
      @mutex.synchronize do
        @cache[downcased_nick] ||= User.new(*bargs, @bot)
      end
    end

    # Finds a user.
    #
    # @param [String] nick nick of a user
    # @return [User, nil]
    def find(nick)
      downcased_nick = nick.irc_downcase(@bot.irc.isupport["CASEMAPPING"])
      @cache[downcased_nick]
    end

    # @api private
    def update_nick(user)
      @mutex.synchronize do
        @cache[user.nick.irc_downcase(@bot.irc.isupport["CASEMAPPING"])] = user
        @cache.delete user.last_nick.irc_downcase(@bot.irc.isupport["CASEMAPPING"])
      end
    end

    # @api private
    def delete(user)
      @cache.delete_if {|n, u| u == user }
    end
  end
end
