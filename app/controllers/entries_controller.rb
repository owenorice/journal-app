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
    if @entry.save
      redirect_to root_url
    else
      render :new
    end
  end

  def update
    @entry = Entry.find(params[:id])
    if @entry.update(entry_params)
      @entry.icon_image.purge_later if params[:purge_icon_image] == "1" && !params.dig(:entry, :icon_image)
      redirect_to root_url, notice: "#{@entry.name} updated."
    else
      redirect_to root_url, alert: "Could not update entry."
    end
  end

  def water
    @entry = Entry.find(params[:id])
    @entry.water!
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
