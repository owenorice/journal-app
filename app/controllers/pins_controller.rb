class PinsController < ApplicationController
  def create
    entry = Entry.find(params[:pin][:entry_id])

    # If this entry already has a pin, move it (upsert by entry)
    @pin = entry.pin || Pin.new(entry: entry)
    was_persisted = @pin.persisted?

    @pin.x_percent = params[:pin][:x_percent]
    @pin.y_percent = params[:pin][:y_percent]

    if @pin.save
      respond_to do |format|
        format.turbo_stream do
          streams = []
          # For a move: remove the stale DOM node, then re-append the updated one
          streams << turbo_stream.remove("pin-#{@pin.id}") if was_persisted
          streams << turbo_stream.append("pins-container",
                       partial: "pins/pin", locals: { pin: @pin })
          render turbo_stream: streams
        end
        format.json { render json: @pin, status: was_persisted ? :ok : :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: @pin.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @pin = Pin.find(params[:id])
    @pin.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("pin-#{@pin.id}")
      end
      format.json { head :no_content }
    end
  end

  private

  def pin_params
    params.require(:pin).permit(:x_percent, :y_percent, :entry_id)
  end
end
