require 'csv'

module Dashboard
  class EntriesController < Dashboard::BaseController
    before_filter :require_current_challenge, only: :index
    load_and_authorize_resource
    def index
      add_crumb 'Propuestas'
      @challenges = organization_challenges
      @current_challenge = current_challenge
      @entries = current_challenge_entries
      @entries.map! { |e| EntryDecorator.new(e) }
      @current_phase = Phases.current_phase_title(current_challenge).title

      respond_to do |format|
        format.html
        format.csv { send_data *dashboard_csv_for(Entry, @entries) }
      end
    end

    def show
      add_crumb 'Propuestas', dashboard_entries_path(challenge_id: entry.challenge_id)
      @entry = entry
      add_crumb entry.name
      @finalists_count = @entry.challenge.current_finalists.count
    end

    def mark_valid
      redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), notice: t('flash.entries.marked_as_valid_successfully', name: entry.name) if entry.mark_as_valid!
    end

    def mark_invalid
      if entry.mark_as_invalid!(params[:message])
        # do we need to do something here?
        EntriesMailer.delay.entry_has_been_marked_as_invalid(entry)
        redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), notice: t('flash.entries.marked_as_invalid_successfully', name: entry.name)
      else
        redirect_to dashboard_entry_path(entry), alert: t('flash.entries.mark_entry_as_invalid_failed')
      end

    end

    def publish
      entry.publish!
      entry.save
      redirect_to dashboard_entries_path(challenge_id: entry.challenge_id)
    end

    def accept
      entry.accept!
      entry.save
      EntriesMailer.entry_accepted(entry).deliver
      redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), notice: t('flash.entries.accepted_successfully')
    end

    def winner
      entry.select_as_winner
      begin
        entry.save
        redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), notice: t('flash.entries.winner_selected_successfully', name: entry.name)
      rescue
        redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), alert: t('flash.entries.no_more_than_3_winners', name: entry.name)
      end
    end

    def remove_winner
      entry.remove_as_winner
      entry.save
      redirect_to dashboard_entries_path(challenge_id: entry.challenge_id), notice: t('flash.entries.winner_removed_successfully')
    end

    private

    def current_challenge_entries
      default = current_challenge.entries.order('created_at DESC').includes(:challenge, member: :user)

      if params[:filter] == 'accepted'
        default.accepted
      else
        default
      end
    end

    def entry
      @_entry ||= Entry.find(params[:id])
    end
  end
end
