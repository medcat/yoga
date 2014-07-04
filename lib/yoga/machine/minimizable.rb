module Yoga
  class Machine
    module Minimizable

      def minimal?
        starting.size == 1 && accepting.size == 1
      end

      def minimize!
        @minimizing = true
        change_made = true
        count = 100
        i = 0

        while change_made
          ary = [
            minimize_epsilon_transitions,
            minimize_parts
          ]
          change_made = ary.any?

          p ary
        end

        #minimize_nondistinct!
        # Minimize parts again because nondistinct likes to leave
        # parts that are not on the path from a starting part.
        #minimize_parts!
        @minimizing = false

        self
      end

      def minimize
        clone.minimize!
      end

      # Make sure that there is only one starting state and one
      # accepting state.
      def minimize_starting
        return false if deterministic?
        changed = false

        raise NoPartError,
          "Machine contains no starting parts" unless starting.any?
        raise NoPartError,
          "Machine contains no accepting parts" unless accepting.any?


        if starting.size > 1
          new_starting = parts.create

          starting.each do |start|
            new_starting.transitions.create(type: :epsilon, to: start)
            start.starting = false
          end

          new_starting.starting = true
          changed = true
        end

        if accepting.size > 1
          new_ending = parts.create

          accepting.each do |accept|
            accept.transitions.create(type: :epsilon, to: new_ending)
            accept.accepting = false
          end

          new_ending.accepting = true
          changed = true
        end

        changed
      end

      # Remove excess epsilon transitions.
      def minimize_epsilon_transitions
        return false if deterministic?
        change_made = false

        parts.each do |part|
          part.transitions.select(&:epsilon?).each do |transition|
            to_state = transition.to
            if to_state.transitions.all? { |_| _.to != part }
              part.transitions.merge(to_state.transitions)
              part.transitions.delete(transition)
              part.accepting = part.accepting? || to_state.accepting?
              part.starting = part.starting? || to_state.starting?
              parts.delete(to_state)

              parts.each do |p|
                p.transitions.each do |trans|
                  if trans.to == to_state
                    trans.to = part
                  end
                end
              end
              change_made = true
            elsif to_state == part
              part.transitions.delete(transition)
              change_made = true
            end
          end
        end

        change_made
      end

      # Removes parts that are not on a path from a starting state
      # to an accepting state.
      def minimize_parts
        acceptable = Set.new

        starting.each do |start|
          path = leads_to_accepting?(start)

          acceptable.merge(path) if path
        end

        acceptable.select! { |_| leads_to_accepting?(_) }
        destroyed = self.parts - acceptable

        parts.each do |part|
          part.transitions.reject! do |transition|
            destroyed.include?(transition.to)
          end
        end

        self.parts = acceptable

        destroyed.any?
      end

      # Combines transitions that lead to the same state.
      def minimize_transitions(allow_exclusion = false)
        parts.each do |part|
          transitionables = part.transitions.group_by { |t| t.to }
          transitions = Set.new

          transitionables.each do |to, trans|
            with = Transition.new(:inclusion)

            trans.each do |transition|
              case transition.type
              when :inclusion
                with.on.merge(transition.on)
              when :exclusion
                with.on.merge(alphabet - transition.on)
              when :epsilon
                with.type = :epsilon
              end
            end

            if allow_exclusion && !with.type?(:epsilon) &&
                with.on.size > (alphabet.size / 2)
              with.type = :exclusion
              with.on = alphabet - with.on
            end

            with.to = to
            transitions << with
          end

          part.transitions = transitions
        end

        self
      end

      def minimize_nondistinct
        return self unless deterministic?
        distinct = {}

        parts.to_a.combination(2) do |p, q|
          check = [p, q].sort
          if (p.accepting? && !q.accepting?) ||
             (!p.accepting? && q.accepting?)
            distinct[check] = :epsilon
          else
            distinct[check] = nil
          end
        end

        changes = 1

        until changes.zero?
          changes = 0
          parts.to_a.combination(2) do |p, q|
            check = [p, q].sort
            alphabet.each do |c|
              transitionable = [
                p.transition(c),
                q.transition(c)
              ]
              next unless transitionable.all?
              transitionable.sort!
              if distinct[check] == nil && distinct[transitionable] != nil
                puts "change #{distinct[transitionable]} to #{c}"
                changes += 1
                distinct[check] = c
              end
            end
          end
        end

        distinct.each do |(left, right), v|
          next if v

          puts "merging #{left} and #{right}"

          left.transitions.merge(right.transitions)

          parts.each do |part|
            part.transitions.each do |transition|
              transition.to = left if transition.to == right
            end
          end
        end

        self
      end

      private

      def leads_to_accepting?(part)
        touches = Set.new([part])

        fixed_point(touches) do
          touches.merge(touches.map(&:transitions).
                        map { |_| _.map(&:to) }.flatten)
        end

        if touches.any?(&:accepting?)
          touches
        elsif part.accepting?
          []
        else
          false
        end
      end

      def fixed_point(enum)
        added = 1

        until added.zero?
          added = enum.size
          yield
          added = enum.size - added
        end
      end
    end
  end
end
