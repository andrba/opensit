require 'textacular/searchable'

class User < ActiveRecord::Base
  attr_accessible :city, :country, :website, :default_sit_length, :dob,
                  :password, :email, :first_name, :gender, :last_name,
                  :practice, :private_diary, :style, :user_type, :username,
                  :who, :why, :password_confirmation, :remember_me, :avatar,
                  :private_stream

  has_many :sits, :dependent => :destroy
  has_many :messages_received, -> { where receiver_deleted: false }, class_name: 'Message', foreign_key: 'to_user_id'
  has_many :messages_sent, -> { where sender_deleted: false }, class_name: 'Message', foreign_key: 'from_user_id'
  has_many :comments, :dependent => :destroy
  has_many :relationships, foreign_key: "follower_id", dependent: :destroy
  has_many :followed_users, through: :relationships, source: :followed
  has_many :reverse_relationships, foreign_key: "followed_id",
                                   class_name:  "Relationship",
                                   dependent:   :destroy
  has_many :followers, through: :reverse_relationships, source: :follower
  has_many :likes, dependent: :destroy
  has_many :notifications, :dependent => :destroy
  has_many :favourites, dependent: :destroy
  has_many :favourite_sits, through: :favourites,
                            source: :favourable,
                            source_type: "Sit"
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Devise :validatable (above) covers validation of email and password
  validates :username, length: { minimum: 3, maximum: 20 }
  validates_uniqueness_of :username
  validates :username, no_empty_spaces: true
  # validates :username, unique_page_name: true

  # Textacular: search these columns only
  extend Searchable(:username, :first_name, :last_name, :city, :country)

  # Pagination: sits per page
  self.per_page = 10

  # Paperclip
  has_attached_file :avatar, styles: {
    small_thumb: '50x50#',
    thumb: '250x250#',
  }

  # Scopes
  scope :newest_first, -> { order("created_at DESC") }
  scope :public, -> { where(private: false) }

  # Used by url_helper to determine user path, eg; /buddha and /user/buddha
  def to_param
    username
  end

  def city?
    !city.blank?
  end

  def country?
    !country.blank?
  end
  ##
  # VIRTUAL ATTRIBUTES
  ##

  # Location based on whether/if city and country have been entered
  def location
    return "#{city}, #{country}" if city? && country?
    return city if city?
    return country if country?
  end

  def display_name
    return username if first_name.blank?
    return first_name if last_name.blank?
    "#{first_name} #{last_name}"
  end

  ##
  # METHODS
  ##

  def latest_sits
    sits.newest_first.limit(3)
  end

  def sits_by_year(year)
    sits.where("EXTRACT(year FROM created_at) = ?", year.to_s)
  end

  def sits_by_month(month: month, year: year)
    sits.where("EXTRACT(year FROM created_at) = ?
      AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0'))
  end

  def stream_range
    return false if self.sits.empty?

    first_sit = Sit.where("user_id = ?", self.id).order(:created_at).first.created_at.strftime("%Y %m").split(' ')
    year, month = Time.now.strftime("%Y %m").split(' ')
    dates = []

    # Build list of all months from first lsit to current date
    while [year.to_s, month.to_s.rjust(2, '0')] != first_sit
      month = month.to_i
      year = year.to_i
      if month != 0
        dates << [year, month]
        month -= 1
      else
        year -= 1
        month = 12
      end
    end

    # Add first sit month
    dates << [first_sit[0].to_i, first_sit[1].to_i]

    # Filter out any months with no activity
    pointer = 1900
    links = []
    dates.each do |m|
      year, month = m
      month_total = self.sits_by_month(month: month, year: year).count

      if pointer != year
        year_total = self.sits_by_year(year).count
        links <<  [year, year_total]
      end

      if month_total != 0
        links << [month, month_total]
      end

      pointer = year
    end

    return links
  end

  def socialstream
    Sit.from_users_followed_by(self).newest_first
  end

  def private_stream=(value)
    unless value.downcase == 'true' || value.downcase == 'false'
      raise ArgumentError, "Argument must be either 'true' or 'false'"
    end
    sits.update_all(private: value)
    write_attribute(:private_stream, value)
  end

  def favourited?(sit_id)
    favourites.where(favourable_type: "Sit", favourable_id: sit_id).exists?
  end

  def following?(other_user)
    relationships.find_by_followed_id(other_user.id) ? true : false
  end

  def follow!(other_user)
    relationships.create!(followed_id: other_user.id)
    Notification.send_notification('NewFollower', other_user.id, { follower: self })
  end

  def unfollow!(other_user)
    relationships.find_by_followed_id(other_user.id).destroy
  end

  def unread_count
    messages_received.unread.count unless messages_received.unread.count.zero?
  end

  def new_notifications
    notifications.unread.count unless notifications.unread.count.zero?
  end

  # Overwrite Devise function to allow profile update with password requirement
  # http://stackoverflow.com/questions/4101220/rails-3-devise-how-to-skip-the-current-password-when-editing-a-registratio?rq=1
  def update_with_password(params={})
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end
    update_attributes(params)
  end

  # LIKES

  def like!(obj)
    Like.create!(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id)
  end

  def likes?(obj)
    Like.where(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id).present?
  end

  def unlike!(obj)
    like = Like.where(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id).first
    like.destroy
  end

  # STATS

  def last_update
    self.sits.newest_first.first.created_at
  end

  def streak_breaker
    if self.streak.nonzero?
      if self.sits.yesterday.empty?
        self.streak = 0
        self.save!
      end
    end
  end

  ##
  # CLASS METHODS
  ##

  def self.newest_users(count = 5)
    self.limit(count).newest_first
  end

  def self.active_users
    User.all.where(private_stream: false).order('sits_count DESC')
  end

  ##
  # CALLBACKS
  ##

  after_create :welcome_email, :follow_opensit

  private

    def welcome_email
      UserMailer.welcome_email(self).deliver
    end

    def follow_opensit
      relationships.create!(followed_id: 97)
    end

end

# == Schema Information
#
# Table name: users
#
#  authentication_token   :string(255)
#  avatar_content_type    :string(255)
#  avatar_file_name       :string(255)
#  avatar_file_size       :integer
#  avatar_updated_at      :datetime
#  city                   :string(255)
#  confirmation_sent_at   :datetime
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  country                :string(255)
#  created_at             :datetime         not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string(255)
#  default_sit_length     :integer          default(30)
#  dob                    :date
#  email                  :string(255)
#  encrypted_password     :string(128)      default(""), not null
#  failed_attempts        :integer          default(0)
#  first_name             :string(255)
#  gender                 :integer
#  id                     :integer          not null, primary key
#  last_name              :string(255)
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string(255)
#  locked_at              :datetime
#  password_salt          :string(255)
#  practice               :text
#  private_diary          :boolean
#  private_stream         :boolean          default(FALSE)
#  remember_created_at    :datetime
#  remember_token         :string(255)
#  reset_password_sent_at :datetime
#  reset_password_token   :string(255)
#  sign_in_count          :integer          default(0)
#  style                  :string(100)
#  unlock_token           :string(255)
#  updated_at             :datetime         not null
#  user_type              :integer
#  username               :string(255)
#  website                :string(100)
#  who                    :text
#  why                    :text
#
