class EntriesController < ApplicationController
  def index
    @entries = Entry.by_watering_urgency
    @pins    = Pin.all
  end

  def new
    @entry = Entry.new
  end

  def create
    @entry = Entry.new(entry_params)
    @entry.last_modified_by = current_user
    if @entry.save
      redirect_to root_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @entry = Entry.find(params[:id])
    @entry.assign_attributes(entry_params)
    @entry.last_modified_by = current_user
    if @entry.save
      @entry.icon_image.purge_later if params[:purge_icon_image] == "1" && !params.dig(:entry, :icon_image)
      redirect_to root_url, notice: "#{@entry.name} updated."
    else
      redirect_to root_url, alert: "Could not update entry: #{@entry.errors.full_messages.to_sentence}."
    end
  end

  def water
    @entry = Entry.find(params[:id])
    @entry.water!(by: current_user)
    redirect_to root_url, notice: "#{@entry.name} watered! 💧"
  end

  def destroy
    Entry.find(params[:id]).destroy
    redirect_to root_url
  end

  private

  def entry_params
    params.require(:entry).permit(:name, :watering_frequency, :notes, :icon, :icon_image)
  end
end
