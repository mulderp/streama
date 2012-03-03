module Streama
  module Activity
    extend ActiveSupport::Concern

    included do

      include Mongoid::Document
      include Mongoid::Timestamps

      field :verb,          :type => Symbol
      field :actor,         :type => Hash
      field :object,        :type => Hash
      field :target_object, :type => Hash
      field :receivers,     :type => Array

      index :name
      index [['actor._id', Mongo::ASCENDING], ['actor._type', Mongo::ASCENDING]]
      index [['object._id', Mongo::ASCENDING], ['object._type', Mongo::ASCENDING]]
      index [['target_object._id', Mongo::ASCENDING], ['target_object._type', Mongo::ASCENDING]]
      index [['receivers.id', Mongo::ASCENDING], ['receivers.type', Mongo::ASCENDING]]

      validates_presence_of :actor, :verb
      before_save :assign_data

    end

    module ClassMethods

      # Defines a new activity type and registers a definition
      #
      # @param [ String ] name The name of the activity
      #
      # @example Define a new activity
      #   activity(:enquiry) do
      #     actor :user, :cache => [:full_name]
      #     object :enquiry, :cache => [:subject]
      #     target_object :listing, :cache => [:title]
      #   end
      #
      # @return [Definition] Returns the registered definition
      def activity(name, &block)
        definition = Streama::DefinitionDSL.new(name)
        definition.instance_eval(&block)
        Streama::Definition.register(definition)
      end

      # Publishes an activity using an activity name and data
      #
      # @param [ String ] verb The verb of the activity
      # @param [ Hash ] data The data to initialize the activity with.
      #
      # @return [Streama::Activity] An Activity instance with data
      def publish(verb, data)
        receivers = data.delete(:receivers)
        new({:verb => verb}.merge(data)).publish(:receivers => receivers)
     #   actor = data.delete(:actor)
     #   new({:verb => verb}.merge(data)).publish(:actor => actor, :receivers => receivers)
      end

      def stream_for(actor, options={})
        query = {:receivers => {'$elemMatch' => {:id => actor.id, :type => actor.class.to_s}}}
        query.merge!({:verb => options[:type]}) if options[:type]
        self.where(query).without(:receivers).desc(:created_at)
      end

    end


    # Publishes the activity to the receivers
    #
    # @param [ Hash ] options The options to publish with.
    #
    def publish(options = {})
      self.actor = load_instance(:actor)
#      self.actor = load_actor(options[:actor])
      # puts actor, options, "follower: #{actor.followers}"
      self.receivers = (options[:receivers] || actor.followers).map { |r| { :id => r.id, :type => r.class.to_s } }
      self.save
      self
    end

    # Returns an instance of an actor, object or target
    #
    # @param [ Symbol ] type The data type (actor, object, target) to return an instance for.
    #
    # @return [Mongoid::Document] document A mongoid document instance
    def load_instance(type)
      (data = self.send(type)).is_a?(Hash) ? data['type'].to_s.camelcase.constantize.find(data['id']) : data
    end

    def load_actor
      if self.actor.is_a?(Hash)
        actor_hash = self.actor
        actor_hash["type"].to_s.camelcase.constantize.find(actor_hash['id'])
      else
        self.actor
      end
    end

    def refresh_data
      assign_data
      save(:validate => false)
    end


    def self.to_class_name(object)
      object.class.name.underscore.to_sym
    end

    def assign_actor
      return unless actor = load_actor

      class_sym = Activity.to_class_name(actor)

      raise Streama::InvalidData.new(class_sym) unless definition.actor.has_key?(class_sym)

      hash = {'id' => actor.id, 'type' => actor.class.name}

      if (fields = definition.actor_fields(class_sym))
        fields.each do |field|
          raise Streama::InvalidField.new(field) unless actor.respond_to?(field)
          hash[field.to_s] = actor.send(field)
        end
      end
      write_attribute(:actor, hash)
    end

    protected

    def assign_data

      assign_actor
      [:object, :target_object].each do |type|
        next unless object = load_instance(type)

        class_sym = Activity.to_class_name(object)
          # object.class.name.underscore.to_sym

        act_definition = definition.send(type)

        raise Streama::InvalidData.new(class_sym) unless act_definition.has_key?(class_sym)

        hash = {'id' => object.id, 'type' => object.class.name}

        if (fields = definition.fields_array(type, class_sym))
          fields.each do |field|
            raise Streama::InvalidField.new(field) unless object.respond_to?(field)
            hash[field.to_s] = object.send(field)
          end
        end
        write_attribute(type, hash)
      end
    end

    def definition
      @definition ||= Streama::Definition.find(verb)
    end

  end
end
