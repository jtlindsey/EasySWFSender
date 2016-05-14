class Formroute < ActiveRecord::Base
  belongs_to :user
  validates :name, length: { minimum: 3, maximum: 15 }
  validates :name, presence: true
  validates :page, presence: true
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :fwd_to_email, presence: true, length: { maximum: 255 }, format: { with: VALID_EMAIL_REGEX }

  before_create :generateKey

  def generateKey
    range = [*'0'..'9', *'a'..'z']
    begin
      newkey = Array.new(15){range.sample}.join
    end while checkExistence(newkey)
    self.key = newkey
  end

  def checkExistence(newkey)
    Formroute.exists?(key: newkey)
  end

  def self.errorMsgs
      @e ||= {"codeErrors": []}
  end

  def self.authenticateMessage(request, params)
    errorMsgs
    current_uri_key = request.env["action_dispatch.request.path_parameters"][:key]
    formroute = Formroute.find_by(key: current_uri_key)
    if formroute != nil
      if emptyTag(params, request) == true && authenticateSource(formroute, request) == true 
      # Save message to db 
      amessage = Message.create(
          fwd_msg_to: formroute[:fwd_to_email], 
          msg_from_site: request.referrer, 
          msg_from_email: params["email"], 
          msg_from_name: params["name"],
          msg_from_ipaddress: request.remote_ip, 
          msg_subject: params["_subject"], 
          msg: params["message"])
      # Then forward message to email associated with form
      FormMailer.new_email(formroute, amessage).deliver_now
      end
    else
      puts @e[:codeErrors].push("Bad Request, No Matching Formroute")
      puts "The ip the message came from is #{request.remote_ip}"
    end
    return true, @e
  end

  def self.authenticateSource(formroute, request)
    if formroute.page == request.referrer
      true
    else
      puts @e[:codeErrors].push("Bad Match, Came from: #{request.referrer}")
      puts @e[:codeErrors].push("Bad Match, Expected: #{formroute.page}")
      puts "The ip the message came from is #{request.remote_ip}"
    end
  end

  def self.emptyTag(params, request)
    if params["_gotcha"].empty? == true
      true
    else
      puts @e[:codeErrors].push("Bad params, check logs")
      puts "The ip the message came from is #{request.remote_ip}"
    end
  end

end